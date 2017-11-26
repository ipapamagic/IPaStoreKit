//
//  IPaReceipt.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2017/10/19.
//

import UIKit
import openssl
typealias ASN1Attribute = (data: Data, type: Int)
open class IPaReceipt: NSObject {
    func enumerateASN1Attributes(data:Data, block: (ASN1Attribute) -> ())
    {
        var type: Int32 = 0
        var tag: Int32 = 0
        var length = 0
        
        let count = data.count
        
        var receiptBytes = [UInt8](repeating:0, count: count)
        data.copyBytes(to: &receiptBytes, count: count)
        
        var ptr = UnsafePointer<UInt8>?(receiptBytes)
        let end = ptr!.advanced(by: count)
        
        ASN1_get_object(&ptr, &length, &type, &tag, end - ptr!)
        
        if (type != V_ASN1_SET)
        {
            return
        }
        
        while ptr! < end
        {
            ASN1_get_object(&ptr, &length, &type, &tag, end - ptr!)
            if (type != V_ASN1_SEQUENCE) { break }
            
            let sequenceEnd = ptr!.advanced(by: length)
            
            // Parse the attribute type
            let attributeType = asn1ReadInteger(&ptr, sequenceEnd - ptr!)
            
            // Skip attribute version
            asn1ConsumeObject(&ptr, sequenceEnd - ptr!)
            
            // Check the attribute value
            let data = asn1ReadOctectString(&ptr, sequenceEnd - ptr!)
            block((data, attributeType))
            
            // Skip remaining fields
            while ptr! < sequenceEnd
            {
                ASN1_get_object(&ptr, &length, &type, &tag, sequenceEnd - ptr!)
                ptr = ptr?.advanced(by: length)
            }
        }
    }
    func asn1ConsumeObject(_ ptr: UnsafeMutablePointer<UnsafePointer<UInt8>?>, _ l: Int)
    {
        var pClass: Int32 = 0
        var tag: Int32 = 0
        var length: Int = 0
        
        ASN1_get_object(ptr, &length, &tag, &pClass, l)
        ptr.pointee = ptr.pointee?.advanced(by: length)
    }
    
    func asn1ReadInteger(_ ptr: UnsafeMutablePointer<UnsafePointer<UInt8>?>, _ l: Int) -> Int
    {
        var pClass: Int32 = 0
        var tag: Int32 = 0
        var length: Int = 0
        
        var value: Int = 0
        var integer: UnsafeMutablePointer<ASN1_INTEGER>
        
        ASN1_get_object(ptr, &length, &tag, &pClass, l)
        if tag != V_ASN1_INTEGER
        {
            print("ASN1 error: attribute not an integer")
        }
        
        integer = c2i_ASN1_INTEGER(nil, ptr, length)
        value = ASN1_INTEGER_get(integer)
        ASN1_INTEGER_free(integer)
        
        return value
    }
    
    func asn1ReadOctectString(_ ptr: UnsafeMutablePointer<UnsafePointer<UInt8>?>, _ l: Int) -> Data
    {
        var pClass: Int32 = 0
        var tag: Int32 = 0
        var length: Int = 0
        
        ASN1_get_object(ptr, &length, &tag, &pClass, l)
        if tag != V_ASN1_OCTET_STRING
        {
            print("ASN1 error: value not an octet string")
        }
        
        let data = Data(bytes: ptr.pointee!, count: length)
        ptr.pointee = ptr.pointee?.advanced(by: length)
        
        return data
    }
    
    func asn1ReadString(_ ptr: UnsafeMutablePointer<UnsafePointer<UInt8>?>, _ l: Int, _ expectedTag: Int32, _ encoding: String.Encoding) -> String?
    {
        var tag: Int32 = 0
        var pClass: Int32 = 0
        var length: Int = 0
        
        ASN1_get_object(ptr, &length, &tag, &pClass, l)
        
        if tag != expectedTag
        {
            print("ASN1 error: value not a string")
        }
        
        let data = Data(bytes: ptr.pointee!, count: length)
        ptr.pointee = ptr.pointee?.advanced(by: length)
        
        return String(data: data, encoding: encoding)
    }
    
    func asn1ReadUTF8String(_ ptr: UnsafeMutablePointer<UnsafePointer<UInt8>?>, _ l: Int) -> String?
    {
        return asn1ReadString(ptr, l, V_ASN1_UTF8STRING, .utf8)
    }
    
    func asn1ReadASCIIString(_ ptr: UnsafeMutablePointer<UnsafePointer<UInt8>?>, _ l: Int) -> String?
    {
        return asn1ReadString(ptr, l, V_ASN1_IA5STRING, .ascii)
    }

}
