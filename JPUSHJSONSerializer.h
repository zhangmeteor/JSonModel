//  Created by zhanghao
//  History:<author>   <time>  <version>   <desc>
//          zhanghao   14-12-1   1.0.0

#import <Foundation/Foundation.h>

@interface JPUSHJSONSerializer : NSObject

/**
*   serialization using default encoding(NSISOLatin1StringEncoding) for NSData.
*   getJSONDataFromObject used to serialize from object to jsonDictionary
*   getObjectFromJSON used to unSerialize from jsonDictionary to object.
*/
 + (NSDictionary *)getJSONDataFromObject:(id)theObject;

 + (id)getObjectFromJSON:(NSDictionary *)jsonData;

/**
*   serialization using appointed encoding for NSData.
*/
 + (NSDictionary *)getJSONDataFromObject:(id)theObject usingEncoding:(NSStringEncoding)encoding;

 + (id)getObjectFromJSON:(NSDictionary *)jsonDic usingEncoding:(NSStringEncoding)encoding;
@end