//
//  DBHelper.m


#import "DBHelper.h"
#import <sqlite3.h>

@interface DBHelper()

@property (nonatomic, strong) NSString* documentsDirectory;
@property (nonatomic, strong) NSString* databaseFile;
@property (nonatomic) sqlite3* sqlite3Database;
@property (nonatomic) BOOL inATransaction;

-(void)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable withArguments:(NSArray*)arguments;

@end

@implementation DBHelper


-(instancetype)initWithDatabaseFilename:(NSString *)fileName {
    self = [super init];
    if (self) {
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        self.documentsDirectory = [paths objectAtIndex:0];
        
        self.databaseFile = fileName;
        self.inATransaction = NO;
    }
    return self;
}

-(void)beginTransaction {
    @synchronized(self) {
        if (self.sqlite3Database != NULL || self.inATransaction == YES) {
            @throw NSInternalInconsistencyException;
            return;
        }
        NSString* databasePath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFile];
        BOOL openDatabaseResult = sqlite3_open([databasePath UTF8String], &_sqlite3Database);
        if (openDatabaseResult == SQLITE_OK) {
            self.inATransaction = YES;
            sqlite3_exec(self.sqlite3Database, "BEGIN", 0, 0, 0);
        } else {
            NSLog(@"SYNC_DB Error: %s", sqlite3_errmsg(self.sqlite3Database));
        }
    }
}

-(void)commitTransaction {
    @synchronized(self) {
        if (self.sqlite3Database == NULL || self.inATransaction == NO) {
            @throw NSInternalInconsistencyException;
            return;
        }
        if (sqlite3_exec(self.sqlite3Database, "COMMIT", 0, 0, 0) != SQLITE_OK) {
            NSLog(@"SYNC_DB Error: %s", sqlite3_errmsg(self.sqlite3Database));
        }
        sqlite3_close(self.sqlite3Database);
        _sqlite3Database = NULL;
        self.inATransaction = NO;
    }
}

-(void)rollbackTransaction {
    @synchronized(self) {
        if (self.sqlite3Database == NULL || self.inATransaction == NO) {
            @throw NSInternalInconsistencyException;
            return;
        }
        if (sqlite3_exec(self.sqlite3Database, "ROLLBACK", 0, 0, 0) != SQLITE_OK) {
            NSLog(@"SYNC_DB Error: %s", sqlite3_errmsg(self.sqlite3Database));
            @throw NSInternalInconsistencyException;
        }
        sqlite3_close(self.sqlite3Database);
        _sqlite3Database = NULL;
        self.inATransaction = NO;
    }
}

-(NSArray*)rawQuery:(NSString *)queryString {
    [self runQuery:[queryString UTF8String] isQueryExecutable:NO withArguments:nil];
    return (NSArray*)[self.result copy];
}

-(void)executeNonQuery:(NSString *)statement {
    [self runQuery:[statement UTF8String] isQueryExecutable:YES withArguments:nil];
}

-(NSArray*)rawQuery:(NSString *)queryString withArguments:(NSArray *)arguments{
    [self runQuery:[queryString UTF8String] isQueryExecutable:NO withArguments:arguments];
    return (NSArray*)[self.result copy];
}

-(void)executeNonQuery:(NSString *)statement withArguments:(NSArray *)arguments{
    [self runQuery:[statement UTF8String] isQueryExecutable:YES withArguments:arguments];
}


-(void)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable withArguments:(NSArray*)arguments{
    
    @synchronized(self) {
        
        NSString* databasePath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFile];
        
        if (self.result != nil) {
            [self.result removeAllObjects];
            self.result = nil;
        }
        self.result = [[NSMutableArray alloc] init];
        
        BOOL openDatabaseResult;
        if (self.inATransaction == NO) {
            openDatabaseResult = sqlite3_open([databasePath UTF8String], &_sqlite3Database);
        } else {
            openDatabaseResult = SQLITE_OK;
        }
        
        if (openDatabaseResult == SQLITE_OK) {
            sqlite3_stmt *compiledStatement;
            
            BOOL preparedStatementResult = sqlite3_prepare_v2(self.sqlite3Database, query, -1, &compiledStatement, NULL);
            if (preparedStatementResult == SQLITE_OK) {
                
                if (arguments != nil) {
                    int i = 1;
                    for (NSString* arg in arguments) {
                        const char* param = (arg == nil ? NULL : [arg UTF8String]);
                        sqlite3_bind_text(compiledStatement, i, param, -1, SQLITE_TRANSIENT);
                        i++;
                    }
                }
                
                if (!queryExecutable) {
                    while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
                        
                        NSMutableDictionary* rowResult = [[NSMutableDictionary alloc] init];
                        
                        int totalColumns = sqlite3_column_count(compiledStatement);
                        for (int i = 0; i < totalColumns; i++) {
                            char* dbDataAsChars = (char* )sqlite3_column_text(compiledStatement, i);
                            if (dbDataAsChars != NULL) {
                                NSString* value = [NSString stringWithUTF8String:dbDataAsChars];
                                NSString* key = [NSString stringWithUTF8String:(char*)sqlite3_column_name(compiledStatement, i)];
                                [rowResult setObject:value forKey:key];
                            }
                        }
                        [self.result addObject:rowResult];
                    }
                } else {
                    if (sqlite3_step(compiledStatement) == SQLITE_DONE) {
                        self.affectedRows = sqlite3_changes(self.sqlite3Database);
                        self.lastInsertedRowID = sqlite3_last_insert_rowid(self.sqlite3Database);
                    } else {
                        NSLog(@"SYNC_DB Error: %s", sqlite3_errmsg(self.sqlite3Database));
                    }
                }
            } else {
                NSLog(@"SYNC_DB Error: %s", sqlite3_errmsg(self.sqlite3Database));
            }
            sqlite3_finalize(compiledStatement);
        } else {
            NSLog(@"SYNC_DB Error: %s", sqlite3_errmsg(self.sqlite3Database));
        }
        if (self.inATransaction == NO) {
            sqlite3_close(self.sqlite3Database);
            _sqlite3Database = NULL;
        }
    }
}

@end
