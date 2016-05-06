//
//  IPaSKReceipt.m
//  IPaSKReceiptVerificator
//
//  Created by IPa Chen on 2015/2/20.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

#import "IPaSKReceipt.h"

#import <openssl/objects.h>
#import <openssl/sha.h>
#import <openssl/x509.h>


// From https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1
//#pragma mark - ANS1
//
//int ASN1ReadInteger(const uint8_t **pp, long omax)
//{
//    int tag, asn1Class;
//    long length;
//    int value = 0;
//    ASN1_get_object(pp, &length, &tag, &asn1Class, omax);
//    if (tag == V_ASN1_INTEGER)
//    {
//        for (int i = 0; i < length; i++)
//        {
//            value = value * 0x100 + (*pp)[i];
//        }
//    }
//    *pp += length;
//    return value;
//}
//
//NSData* ASN1ReadOctectString(const uint8_t **pp, long omax)
//{
//    int tag, asn1Class;
//    long length;
//    NSData *data = nil;
//    ASN1_get_object(pp, &length, &tag, &asn1Class, omax);
//    if (tag == V_ASN1_OCTET_STRING)
//    {
//        data = [NSData dataWithBytes:*pp length:length];
//    }
//    *pp += length;
//    return data;
//}
//
//NSString* ASN1ReadString(const uint8_t **pp, long omax, int expectedTag, NSStringEncoding encoding)
//{
//    int tag, asn1Class;
//    long length;
//    NSString *value = nil;
//    ASN1_get_object(pp, &length, &tag, &asn1Class, omax);
//    if (tag == expectedTag)
//    {
//        value = [[NSString alloc] initWithBytes:*pp length:length encoding:encoding];
//    }
//    *pp += length;
//    return value;
//}
//
//NSString* ASN1ReadUTF8String(const uint8_t **pp, long omax)
//{
//    return ASN1ReadString(pp, omax, V_ASN1_UTF8STRING, NSUTF8StringEncoding);
//}
//
//NSString* ASN1ReadIA5SString(const uint8_t **pp, long omax)
//{
//    return ASN1ReadString(pp, omax, V_ASN1_IA5STRING, NSASCIIStringEncoding);
//}

@implementation IPaSKReceipt
#pragma mark - ANS1

- (int) ASN1ReadInteger:(const uint8_t **)pp omax:(long)omax
{
    int tag, asn1Class;
    long length;
    int value = 0;
    ASN1_get_object(pp, &length, &tag, &asn1Class, omax);
    if (tag == V_ASN1_INTEGER)
    {
        for (int i = 0; i < length; i++)
        {
            value = value * 0x100 + (*pp)[i];
        }
    }
    *pp += length;
    return value;
}
- (NSData*) ASN1ReadOctectString:(const uint8_t **)pp omax:(long)omax
{
    int tag, asn1Class;
    long length;
    NSData *data = nil;
    ASN1_get_object(pp, &length, &tag, &asn1Class, omax);
    if (tag == V_ASN1_OCTET_STRING)
    {
        data = [NSData dataWithBytes:*pp length:length];
    }
    *pp += length;
    return data;
}
- (NSString*) ASN1ReadString:(const uint8_t **)pp omax:(long) omax expectedTag:(int) expectedTag encoding:(NSStringEncoding) encoding
{
    int tag, asn1Class;
    long length;
    NSString *value = nil;
    ASN1_get_object(pp, &length, &tag, &asn1Class, omax);
    if (tag == expectedTag)
    {
        value = [[NSString alloc] initWithBytes:*pp length:length encoding:encoding];
    }
    *pp += length;
    return value;
}
- (NSString*) ASN1ReadUTF8String:(const uint8_t **)pp omax:(long) omax
{
    return [self ASN1ReadString:pp omax:omax  expectedTag:V_ASN1_UTF8STRING encoding:NSUTF8StringEncoding];
}


- (NSString*) ASN1ReadIA5SString:(const uint8_t **)pp omax:(long) omax
{
    return [self ASN1ReadString:pp omax:omax  expectedTag:V_ASN1_IA5STRING encoding:NSASCIIStringEncoding];
}

#pragma mark - Utils




/*
 Based on https://github.com/rmaddy/VerifyStoreReceiptiOS
 */
- (void)enumerateASN1Attributes:(const uint8_t*)p length:(long)tlength usingBlock:(void (^)(NSData *data, int type))block
{
    int type, tag;
    long length;
    
    const uint8_t *end = p + tlength;
    
    ASN1_get_object(&p, &length, &type, &tag, end - p);
    if (type != V_ASN1_SET) return;
    
    while (p < end)
    {
        ASN1_get_object(&p, &length, &type, &tag, end - p);
        if (type != V_ASN1_SEQUENCE) break;
        
        const uint8_t *sequenceEnd = p + length;
        
        const int attributeType = [self ASN1ReadInteger:&p omax:sequenceEnd - p]; // Consume attribute version
        
        NSData *data = [self ASN1ReadOctectString:&p omax: sequenceEnd - p];
        if (data)
        {
            block(data, attributeType);
        }
        
        while (p < sequenceEnd)
        { // Skip remaining fields
            ASN1_get_object(&p, &length, &type, &tag, sequenceEnd - p);
            p += length;
        }
    }
}

- (NSDate*)formatRFC3339String:(NSString*)string
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    NSDate *date = [formatter dateFromString:string];
    return date;
}

@end
