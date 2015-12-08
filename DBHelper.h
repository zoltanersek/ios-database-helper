//
//  DBHelper.h
//
//

#import <Foundation/Foundation.h>

@interface DBHelper : NSObject

@property (nonatomic, strong) NSMutableArray* result;
@property (nonatomic) int affectedRows;
@property (nonatomic) long long lastInsertedRowID;

-(instancetype) initWithDatabaseFilename:(NSString*)fileName;

-(void)beginTransaction;
-(void)commitTransaction;
-(void)rollbackTransaction;

-(NSArray*)rawQuery:(NSString*)queryString;
-(void)executeNonQuery:(NSString*)statement;

-(NSArray*)rawQuery:(NSString*)queryString withArguments:(NSArray*)arguments;
-(void)executeNonQuery:(NSString*)statement withArguments:(NSArray*)arguments;


@end
