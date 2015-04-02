/*-----------------------------------------------------------------------------
  Copyright (c) 2012年 HXHG. All rights reserved.
  Version: 1.8.3
  FileName:JPUSHFileCache.m
  Date:14-11-27
  Description: json serializer
  Author: Zhanghao
  History:<author>     <time>   <version>         <desc>
  Note:
-------------------------------------------------------------------------------*/
#import <objc/runtime.h>
#import "JPUSHJSONSerializer.h"

#define JPF_HAS_CUSTOM_OBJECT (@"hasCustomObject")
#define JPF_CLASS_NAME (@"className")

#define JPF_SET_OBJECT (@"setObject")
#define JPF_DICTIONARY_OBJECT (@"dictionaryObject")
#define JPF_ARRAY_OBJECT (@"arrayObject")
#define JPF_DATA_OBJECT (@"dataObject")
#define JPF_NUMBER_OBJECT (@"numberObject")
#define JPF_STRING_OBJECT (@"stringObject")
#define JPF_NULL_OBJECT (@"nullObject")

static NSStringEncoding dataEncoding = NSISOLatin1StringEncoding;

#pragma mark - JSONAutoSerializer

@interface JPUSHJSONSerializer ()
 + (NSMutableArray *)p_getPropertyList:(id)theObject;

 + (id)p_JSONSerializeCustomObject:(id)theObject with:(BOOL *)hasCustomObject;

 + (id)p_serializeNSDictionary:(NSDictionary *)dictionary with:(BOOL *)hasCustomObject;

 + (id)p_serializeData:(NSData *)data with:(BOOL *)hasCustomObject;

 + (id)p_serializeNumber:(NSNumber *)number with:(BOOL *)hasCustomObject;

 + (id)p_serializeString:(NSString *)string with:(BOOL *)hasCustomObject;

 + (id)p_serializeNull:(NSNull *)null with:(BOOL *)hasCustomObject;

 + (id)p_serializeNSSet:(NSSet *)set with:(BOOL *)hasCustomObject;

 + (id)p_serializeNSArray:(NSArray *)array with:(BOOL *)hasCustomObject;

 + (id)p_serializeObject:(id)object with:(BOOL *)hasCustomObject;

 + (id)p_JSONUnSerializeCustomObject:(NSDictionary *)jsonDictionary;

 + (NSMutableDictionary *)p_UnSerializeNSDictionary:(NSDictionary *)dictionary;

 + (NSMutableSet *)p_unSerializeNSSet:(id)objc;

 + (NSMutableArray *)p_unSerializeNSArray:(NSArray *)array;

 + (id)p_unSerializeObject:(id)object;
@end

@implementation JPUSHJSONSerializer

+ (NSDictionary *)getJSONDataFromObject:(id)theObject{
  BOOL hasCustomObject = FALSE;
  id serializeObject = [self p_serializeObject:theObject with:&hasCustomObject];
  if ([serializeObject isKindOfClass:[NSNumber class]]){
    serializeObject = [self p_serializeNumber:serializeObject with:&hasCustomObject];
  }else if ([serializeObject isKindOfClass:[NSString class]]){
    serializeObject = [self p_serializeString:serializeObject with:&hasCustomObject];
  }else if ([serializeObject isKindOfClass:[NSNull class]]){
//    serializeObject = [self p_serializeNull:serializeObject with:&hasCustomObject];
    serializeObject = nil;
  }else if ([serializeObject isKindOfClass:[NSData class]]){
      serializeObject = [self p_serializeData:serializeObject with:&hasCustomObject];
  }
//  NSData *jsonData = JPUSHJSONData(serializeObject);
//  return jsonData;
  return serializeObject;
}

+ (id)getObjectFromJSON:(NSDictionary *)jsonDictionary {
//  id jsonObject = JPUSHJSONObject(jsonData);
  if (jsonDictionary) {
    id resultObject = [self p_unSerializeObject:jsonDictionary];
    return resultObject;
  } else {
    return nil;
  }
}

+ (NSDictionary *)getJSONDataFromObject:(id)theObject usingEncoding:(NSStringEncoding)encoding {
  dataEncoding = encoding;
  return [self getJSONDataFromObject:theObject];
}

+ (id)getObjectFromJSON:(NSDictionary *)jsonDic usingEncoding:(NSStringEncoding)encoding {
  dataEncoding = encoding;
  return [self getObjectFromJSON:jsonDic];
}


+ (NSMutableArray *)p_getPropertyList:(id)theObject {
  NSString *className = NSStringFromClass([theObject class]);
  const char *cClassName = [className UTF8String];
  id theClass = objc_getClass(cClassName);
  unsigned int outCount;
  objc_property_t *properties = class_copyPropertyList(theClass, &outCount);
    
    if (outCount == 0) {
        free(properties);
        return nil;
    }

  NSMutableArray *propertyNames = [[NSMutableArray alloc] initWithCapacity:1];
  for (unsigned int i = 0; i < outCount; ++i) {
      @autoreleasepool {
          objc_property_t property = properties[i];
          const char *propertyName = property_getName(property);
          NSString *propertyNameString =
          [[NSString alloc] initWithCString:propertyName
                                   encoding:NSUTF8StringEncoding];
          [propertyNames addObject:propertyNameString];
      }
  }

  free(properties);
  return propertyNames;
}

#pragma mark - particular type Object Serialize
+ (id)p_JSONSerializeCustomObject:(id)theObject with:(BOOL *)hasCustomObject {
    if (!theObject) {
      return nil;
    }
  NSMutableArray *propertyNames = [self p_getPropertyList:theObject];

  NSMutableDictionary *finalDict =
            [[NSMutableDictionary alloc] initWithCapacity:2];
    NSString *className = NSStringFromClass([theObject class]);
    if (className) {
      finalDict[JPF_CLASS_NAME] = className;
    }
    //  finalDict[JPF_HAS_CUSTOM_OBJECT] = @(FALSE);
    //  __block BOOL subObjectHasCustomObject = FALSE;

    [propertyNames enumerateObjectsUsingBlock:^(NSString *object, NSUInteger idx,
            BOOL *stop) {
      SEL selector = NSSelectorFromString(object);
      id value = nil;
      if ([theObject respondsToSelector:selector]) {
        value = [theObject valueForKey:object];
      }
      BOOL tempCustomObject = TRUE;
      id serializeObject = [self p_serializeObject:value with:&tempCustomObject];

      if (serializeObject) {
        finalDict[object] = serializeObject;
      }
      //    if (!subObjectHasCustomObject & tempCustomObject) {
      //      subObjectHasCustomObject = tempCustomObject;
      //    }
    }];

    //  if (subObjectHasCustomObject){
    //    *hasCustomObject = TRUE;
    //    finalDict[JPF_HAS_CUSTOM_OBJECT] = @(subObjectHasCustomObject);
    //  }
    return finalDict;
  }

+ (id)p_serializeNSDictionary:(NSDictionary *)dictionary with:(BOOL *)hasCustomObject {
    NSMutableDictionary *finalDict =
            [[NSMutableDictionary alloc] initWithCapacity:2];
    __block NSMutableDictionary *newDictionary =
            [[NSMutableDictionary alloc] initWithCapacity:1];
    __block BOOL subObjectHasCustomObject = FALSE;

    [dictionary
            enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
              BOOL tempCustomObject = FALSE;
              id serializeObject = [self p_serializeObject:object with:&tempCustomObject];
              if (serializeObject) {
                newDictionary[key] = serializeObject;
              }
              if (!subObjectHasCustomObject & tempCustomObject) {
                subObjectHasCustomObject = tempCustomObject;
              }
            }];

    if (subObjectHasCustomObject) {
      *hasCustomObject = TRUE;
      finalDict[JPF_HAS_CUSTOM_OBJECT] = @(subObjectHasCustomObject);
    } else {
      return newDictionary;
    }

    finalDict[JPF_DICTIONARY_OBJECT] = [newDictionary mutableCopy];
    return finalDict;
  }

+ (id)p_serializeData:(NSData *)data with:(BOOL *)hasCustomObject {
    NSMutableDictionary *finalDict =
            [[NSMutableDictionary alloc] initWithCapacity:2];
    finalDict[JPF_HAS_CUSTOM_OBJECT] = @(FALSE);
    *hasCustomObject = FALSE;
    if (data) {
//      finalDict[JPF_DATA_OBJECT] =
//              [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
        //TODO:be careful when data has '\0'
//      finalDict[JPF_DATA_OBJECT] = [NSString stringWithFormat:@"%@",data];
      finalDict[JPF_DATA_OBJECT] = [[NSString alloc] initWithData:data encoding:dataEncoding];
    }
    return finalDict;
  }

+ (id) p_serializeNumber:(NSNumber *)number with:(BOOL *)hasCustomObject {
    NSMutableDictionary *finalDict =
            [[NSMutableDictionary alloc] initWithCapacity:2];
    finalDict[JPF_HAS_CUSTOM_OBJECT] = @(FALSE);
    *hasCustomObject = FALSE;
    if (number) {
      finalDict[JPF_NUMBER_OBJECT] = number;
    }
    return finalDict;
  }

+ (id) p_serializeString:(NSString *)string with:(BOOL *)hasCustomObject {
  NSMutableDictionary *finalDict =
          [[NSMutableDictionary alloc] initWithCapacity:2];
  finalDict[JPF_HAS_CUSTOM_OBJECT] = @(FALSE);
  *hasCustomObject = FALSE;
  if (string) {
    finalDict[JPF_STRING_OBJECT] = string;
  }
  return finalDict;
}

+ (id) p_serializeNull:(NSNull *)null with:(BOOL *)hasCustomObject {
  NSMutableDictionary *finalDict =
          [[NSMutableDictionary alloc] initWithCapacity:2];
  finalDict[JPF_HAS_CUSTOM_OBJECT] = @(FALSE);
  *hasCustomObject = FALSE;
  finalDict[JPF_NUMBER_OBJECT] = [NSNull null];
  return finalDict;
}

+ (id)p_serializeNSSet:(NSSet *)set with:(BOOL *)hasCustomObject {
    __block NSMutableDictionary *finalDict =
            [[NSMutableDictionary alloc] initWithCapacity:2];
    //  finalDict[JPF_HAS_CUSTOM_OBJECT] = @(FALSE);
    NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:1];

    __block BOOL subObjectHasCustomObject = FALSE;
    [set enumerateObjectsUsingBlock:^(id object, BOOL *stop) {
      BOOL tempCustomObject = FALSE;
      id serializeObject = [self p_serializeObject:object with:&subObjectHasCustomObject];

      if (serializeObject) {
        [newArray addObject:serializeObject];
      }
      if (!subObjectHasCustomObject & tempCustomObject) {
        subObjectHasCustomObject = tempCustomObject;
      }
    }];
  finalDict[JPF_HAS_CUSTOM_OBJECT] = @(subObjectHasCustomObject);
  if (subObjectHasCustomObject) {
    *hasCustomObject = TRUE;
  }
  finalDict[JPF_SET_OBJECT] = newArray;
  return finalDict;
}

+ (id)p_serializeNSArray:(NSArray *)array with:(BOOL *)hasCustomObject {
    NSMutableDictionary *finalDict =
            [[NSMutableDictionary alloc] initWithCapacity:2];
    //  finalDict[JPF_HAS_CUSTOM_OBJECT] = @(FALSE);
    NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:1];

    __block BOOL subObjectHasCustomObject = FALSE;
    [array enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
      BOOL tempCustomObject = FALSE;
      id serializeObject = [self p_serializeObject:object with:&subObjectHasCustomObject];

      if (serializeObject) {
        [newArray addObject:serializeObject];
      }
      if (!subObjectHasCustomObject & tempCustomObject) {
        subObjectHasCustomObject = tempCustomObject;
      }
    }];
    if (subObjectHasCustomObject) {
      finalDict[JPF_HAS_CUSTOM_OBJECT] = @(subObjectHasCustomObject);
      *hasCustomObject = TRUE;
    } else {
      return newArray;
    }
    finalDict[JPF_ARRAY_OBJECT] = newArray;
    return finalDict;
  }

+ (id)p_serializeObject:(id)object with:(BOOL *)hasCustomObject {
    id theResult = nil;
    if ([object isKindOfClass:[NSNull class]] || object == nil) {
      theResult = nil;
    } else if ([object isKindOfClass:[NSNumber class]]) {
      theResult = object;
    } else if ([object isKindOfClass:[NSString class]]) {
      theResult = object;
    } else if ([object isKindOfClass:[NSArray class]]) {
      theResult = [self p_serializeNSArray:object with:hasCustomObject];
    } else if ([object isKindOfClass:[NSDictionary class]]) {
      theResult = [self p_serializeNSDictionary:object with:hasCustomObject];
    } else if ([object isKindOfClass:[NSSet class]]) {
      theResult = [self p_serializeNSSet:object with:hasCustomObject];
      *hasCustomObject = TRUE;
    } else if ([object isKindOfClass:[NSData class]]) {
      theResult = [self p_serializeData:object with:hasCustomObject];
      *hasCustomObject = TRUE;
    } else {
      theResult = [self p_JSONSerializeCustomObject:object with:hasCustomObject];
      *hasCustomObject = TRUE;
    }
    return theResult;
  }

#pragma mark - particular type Object UnSerialize
+ (id)p_JSONUnSerializeCustomObject:(NSDictionary *)jsonDictionary {
    id resultObject = nil;
    if (jsonDictionary == nil || [jsonDictionary count] == 0) {
      return resultObject;
    }
    id className = jsonDictionary[JPF_CLASS_NAME];
    //  BOOL hasCustomObject = [jsonDictionary[JPF_HAS_CUSTOM_OBJECT] boolValue];

    if (className && [className isKindOfClass:[NSString class]]) {
      id theObject = NSClassFromString(className);
      if (theObject == nil) {
        return resultObject;
      }
      resultObject = [[theObject alloc] init];

      [jsonDictionary
              enumerateKeysAndObjectsUsingBlock:^(NSString *key, id object,
                                              BOOL *stop) {
                                        if (object &&
                                                ![key isEqualToString:JPF_CLASS_NAME] &&
                                                ![key isEqualToString:
                                                        JPF_HAS_CUSTOM_OBJECT]) {
                                          id customObject = [self p_unSerializeObject:object];
                                          if (customObject) {
                                            [resultObject setValue:customObject
                                                            forKey:key];
                                          }
                                        }
                                      }];
    }
    return resultObject;
  }

+ (NSMutableDictionary *)p_UnSerializeNSDictionary:(NSDictionary *)dictionary {
    NSMutableDictionary *finalDict =
            [[NSMutableDictionary alloc] initWithCapacity:1];

    [dictionary
            enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
                                      id unSerializeObject = [self p_unSerializeObject:object];
                                      if (unSerializeObject) {
                                        finalDict[key] = unSerializeObject;
                                      }
                                    }];
    return finalDict;
  }

+ (NSMutableSet *)p_unSerializeNSSet:(id)objc {
  if (![objc count]) {
    return nil;
  }
  NSMutableSet *finalSet = [[NSMutableSet alloc] initWithCapacity:1];
  NSArray *unSerializeSet = objc[JPF_SET_OBJECT];
  BOOL hasCustomValue = [objc[JPF_HAS_CUSTOM_OBJECT] boolValue];

  [unSerializeSet enumerateObjectsUsingBlock:^(id object,NSUInteger idx, BOOL *stop) {
                                     id serializeObject = object;
                                     if (hasCustomValue){
                                       serializeObject = [self p_unSerializeObject:object];
                                     }
                                     if (serializeObject) {
                                       [finalSet addObject:serializeObject];
                                     }
                                   }];
  return finalSet;
}

+ (NSMutableArray *)p_unSerializeNSArray:(NSArray *)array {
    NSMutableArray *finalArray = [[NSMutableArray alloc] initWithCapacity:1];

    [array enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
                              id serializeObject = [self p_unSerializeObject:object];
                              if (serializeObject) {
                                [finalArray addObject:serializeObject];
                              }
                            }];
    return finalArray;
  }

+ (id)p_unSerializeObject:(id)object {
    id theResult = nil;
    if ([object isKindOfClass:[NSNull class]] || object == nil) {
      theResult = nil;
    } else if ([object isKindOfClass:[NSNumber class]]) {
      theResult = object;
    } else if ([object isKindOfClass:[NSString class]]) {
      theResult = [object mutableCopy];
    } else if ([object isKindOfClass:[NSArray class]]) {
        theResult = [object mutableCopy];
    } else if ([object isKindOfClass:[NSDictionary class]]) {
      id className = object[JPF_CLASS_NAME];
      if ([className isKindOfClass:[NSString class]] && [className length]) {
        theResult = [self p_JSONUnSerializeCustomObject:object];
      } else {
        if ([object valueForKey:JPF_DICTIONARY_OBJECT]) {
          NSDictionary *dictionary = object[JPF_DICTIONARY_OBJECT];
          theResult = object[JPF_HAS_CUSTOM_OBJECT]
                  ? [self p_UnSerializeNSDictionary:dictionary]
                  : [dictionary mutableCopy];
        } else if ([object valueForKey:JPF_ARRAY_OBJECT]) {
          NSArray *array = object[JPF_ARRAY_OBJECT];
          theResult = object[JPF_HAS_CUSTOM_OBJECT]
                  ? [self p_unSerializeNSArray:array]
                  : [array mutableCopy];
        } else if ([object valueForKey:JPF_SET_OBJECT]) {
          theResult = [self p_unSerializeNSSet:object];
        } else if ([object valueForKey:JPF_DATA_OBJECT]) {
          NSString *dataString = [[object valueForKey:JPF_DATA_OBJECT] mutableCopy];
          theResult = [dataString dataUsingEncoding:dataEncoding allowLossyConversion:NO];
        } else if ([object valueForKey:JPF_NUMBER_OBJECT]) {
          NSNumber *number = [object valueForKey:JPF_NUMBER_OBJECT];
          theResult = number;
        } else if ([object valueForKey:JPF_STRING_OBJECT]){
          NSString *string = [object valueForKey:JPF_STRING_OBJECT];
          theResult = string;
        }
      }
    } else if ([object isKindOfClass:[NSSet class]]) {
      theResult = object;  // JPFUnSerializeNSSet(object);
    } else {
      theResult = object;  // JPFJSONUnSerializeCustomObject(object);
    }
    return theResult;
  }

@end