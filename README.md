Introduction
======

sproto is an efficient serialization library for C, and focus on lua binding. It's like google protocol buffers, but much faster.

It's designed simple , only support few types that lua support. It can be easy binding to other dynamic languages , or use it directly in C .

In my i5-2500 @3.3GHz CPU, the benchmark is below :

The schema in sproto :

```
.Person {
    name 0 : string
    id 1 : integer
    email 2 : string

    .PhoneNumber {
        number 0 : string
        type 1 : integer
    }

    phone 3 : *PhoneNumber
}

.AddressBook {
    person 0 : *Person
}
```

It's equal to :

```
message Person {
  required string name = 1;
  required int32 id = 2;
  optional string email = 3;

  message PhoneNumber {
    required string number = 1;
    optional int32 type = 2 ;
  }

  repeated PhoneNumber phone = 4;
}

message AddressBook {
  repeated Person person = 1;
}
```

Use the data :
```lua
local ab = {
    person = {
        {
            name = "Alice",
            id = 10000,
            phone = {
                { number = "123456789" , type = 1 },
                { number = "87654321" , type = 2 },
            }
        },
        {
            name = "Bob",
            id = 20000,
            phone = {
                { number = "01234567890" , type = 3 },
            }
        }
    }
}
```

library| encode 1M times | decode 1M times | size
-------| --------------- | --------------- | ----
sproto | 2.15s           | 7.84s           | 83 bytes
sproto (nopack) |1.58s   | 6.93s           | 130 bytes
pbc-lua	  | 6.94s        | 16.9s           | 69 bytes
lua-cjson | 4.92s        | 8.30s           | 183 bytes

* pbc-lua is a google protocol buffers library https://github.com/cloudwu/pbc
* lua-cjson is a json library https://github.com/efelix/lua-cjson

Lua API
=======

```lua
local parser = require "sprotoparser"
```

* `parser.parse` parse a sproto schema to a binary string.

The parser is need for parsing sproto schema , you can use it to generate the binary string offline . The schema text and the parser no need when your program running.

```lua
local sproto = require "sproto.core"
```

* `sproto.newproto(sp)` create a sproto object by a schema string (generate by parser) .
* `sproto.querytype(sp, typename)` query a type object from a sproto object by typename .
* `sproto.encode(st, luatable)` encode a lua table by a type object, and generate a string message.
* `sproto.decode(st, message)` decode the message string generate by sproto.encode with the type .
* `sproto.pack(sprotomessage)` pack the string encode by sproto.encode to reduce the size.
* `sproto.unpack(packedmessage)` unpack the string packing by sproto.pack .

The sproto support protocol tag for RPC , use `sproto.protocol(tagorname)` to convert the protocol name to the tag id, or convert back from tag id to the name.
and returns the request/response message type objects of this protocol .

Schema Language
==========

Like Protocol Buffers (but unlike json) , sproto messages are strongly-typed and not self-describing. You must define your message structure in a special language .

You can use sprotoparser library to parse the schema text to a binary string, so that the sproto library can use it. 
You can parse them offline and save the string , or you can parse them during your program running.

The schema text like this :

```
# This is a comment.

.Person {	# . means a user defined type 
    name 0 : string	# string is a build-in type.
    id 1 : integer
    email 2 : string

    .PhoneNumber {	# user defined type can be nest.
        number 0 : string
        type 1 : integer
    }

    phone 3 : *PhoneNumber	# *PhoneNumber means an array of PhoneNumber.
}

.AddressBook {
    person 0 : *Person
}

foobar 1 {	# define a new protocol (for RPC used) with tag 1
    request person	# Associate the type person with foobar.request
    response {	# define the foobar.response type
        ok 0 : boolean
    }
}

```

A schema text can be self-described by the sproto schema language.

```
.type {
    .field {
        name 0 : string
        type 1 : string
        id 2 : integer
        array 3 : boolean
    }
    name 0 : string
    fields 1 : *field
}

.protocol {
    name 0 : string
    id 1 : integer
    request 2 : string
    response 3 : string
}

.group {
    type 0 : *type
    protocol 1 : *protocol
}
```

Types
=======

* **string** : binary string
* **integer** : integer, the max length of a integer is signed 64bit .
* **boolean** : true or false

You can add * before the typename to declare an array .

User defined type can be any name in alphanumeric characterss except build-in typename , and nest types are supported.

* Where is double or real types ?

I use google protocol buffers many years in many projects, I found the real types were seldom used. If you really need it, you can use string to serialize the double numbers.

* Where is enum ?

In lua , enum types is not very useful . You can use integer and defined an enum table in lua .

Wire protocol
========

Each integer number must be serialized in little-endian format.

The sproto message must be a user defined type struct , and a struct encode as three parts. The header , the field part and the data part. 
The tag and small integer or boolean will encode in field part, others are in data part.

All the fields must encode in ascending order (by tag). The tags of fields can be discontinuous, if a field is nil (default value in lua), don't encode it in message.

The header is two 16bit integer , the first one is the number of field , and the second one is the number of data .

Each field in field part is two 16bit integer, the first one is the tag increment. The base of tags is 0 . If your tags in message in continuous, the tag increment would be zero. 
The second one indicate the value of this field. If it is 0, the real value encode in data part, or minus 1 as the field value.
Read the example below to see more detail.

Notice : If the tag not declare in schema , the decoder will simply ignore the field for protocol version compatibility .

Example 1 :

```
person { name = "Alice" ,  age = 13, marital = false } 

03 00 01 00 (fn = 3, dn = 1)
00 00 00 00 (id = 0, value in data part)
00 00 0E 00 (id = 1, value = 13)
00 00 01 00 (id = 2, value = false)
05 00 00 00 (sizeof "Alice")
41 6C 69 63 65 ("Alice")
```

Example 2:

```
person {
    name = "Bob",
    age = 40,
    children = {
        { name = "Alice" ,  age = 13, marital = false },
    }
}

04 00 02 00 (fn = 4, dn = 2)
00 00 00 00 (id = 0, value in data part)
00 00 29 00 (id = 1, value = 40)
01 00 00 00 (id = 3 / skip id 2, value in data part)

03 00 00 00 (sizeof "Bob")
42 6F 62 ("Bob")

19 00 00 00 (sizeof struct)
03 00 01 00 (fn = 3, dn = 1)
00 00 00 00 (id = 0, ref = 0)
00 00 0E 00 (id = 1, value = 13)
00 00 01 00 (id = 2, value = false)
05 00 00 00 (sizeof "Alice")
41 6C 69 63 65 ("Alice")
```

0 Packing
=======

The algorithm is very similar with [Cap'n proto](http://kentonv.github.io/capnproto/) , but 0x00 is not treated specially. 

In packed format, the message if padding to 8 . Each 8 bytes is reduced to a tag byte followed by zero to eight content bytes. 
The bits of the tag byte correspond to the bytes of the unpacked word, with the least-significant bit corresponding to the first byte. 
Each zero bit indicates that the corresponding byte is zero. The non-zero bytes are packed following the tag.

For example :

```
unpacked (hex):  08 00 00 00 03 00 02 00   19 00 00 00 aa 01 00 00
packed (hex):  51 08 03 02   31 19 aa 01
```

Tag 0xff treated specially. A number N is following the 0xff tag. N means (N+1)*8 bytes should be copied directly. 
The bytes may or may not contain zeros. Because of this rule, the worst-case space overhead of packing is 2 bytes per 2 KiB of input.

For example :

```
unpacked (hex):  8a (x 30 bytes)
packed (hex):  ff 03 8a (x 30 bytes) 00 00
```

C API
=====

```C
struct sproto * sproto_create(const void * proto, size_t sz);
```

Create a sproto object with an schema string encode by sprotoparser.

```C
void sproto_release(struct sproto *);
```

Release the sproto object.

```C
int sproto_prototag(struct sproto *, const char * name);
const char * sproto_protoname(struct sproto *, int proto);
// SPROTO_REQUEST(0) : request, SPROTO_RESPONSE(1): response
struct sproto_type * sproto_protoquery(struct sproto *, int proto, int what);
```

Convert between tag and name of a protocol, and query the type object of it.

```C
struct sproto_type * sproto_type(struct sproto *, const char * typename);
```

Query the type object from a sproto object.

```C
typedef int (*sproto_callback)(void *ud, const char *tagname, int type, int index, struct sproto_type *, void *value, int length);

int sproto_decode(struct sproto_type *, const void * data, int size, sproto_callback cb, void *ud);
int sproto_encode(struct sproto_type *, void * buffer, int size, sproto_callback cb, void *ud);
```

encode and decode the sproto message with a user defined callback function. Read the implementation of lsproto.c for more detail.

```C
int sproto_pack(const void * src, int srcsz, void * buffer, int bufsz);
int sproto_unpack(const void * src, int srcsz, void * buffer, int bufsz);
```

pack and unpack the message with the 0 packing algorithm.

Question ?
==========

* Send me an email : http://www.codingnow.com/2000/gmail.gif
* My Blog : http://blog.codingnow.com
* Design : http://blog.codingnow.com/2014/07/ejoyproto.html (in Chinese)
