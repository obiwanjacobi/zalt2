# Files and Streams

All Device IO functions are Async.

An 'uri' points to a device (or file). This identifies the device as well as any sub-entity (think of a file in a directory on a file-system).

Stupid example:

```
u:0          → UART 0
u:1          → UART 1
s:boot/x.com → SD card, path boot/x.com
p:3          → MMU page 3
r:date       → RTC date
i:           → stdin  (alias)
o:           → stdout (alias)
x:0          → expansion bus device 0
```

`File_Open(uri)` returns a handle that represents the item/entity identified in the uri, created by the specific driver of the targeted device.

`StreamWriter` => `Stream` => `StreamReader` // async api

A `Stream` is always one-way - it's writer produces data which the reader consumes.

For reading, a Device implements the StreamWriter and the client uses a StreamReader to get the data.
For Writing, a Device implement the StreamReader and the client uses a StreamWriter to send the data.

The `Stream` can be a ring-buffer:

```
Reading from SD card:

  [SD hardware]
       │
  FileDesc (sd driver)  ← handle lives here, in the Writer
       │
  StreamWriter ──► [ring buffer] ──► StreamReader
                                           │
                                      application
                                      (no handle — app IS the reader)
```

```
Writing to UART:

  application
  (no handle — app IS the writer)
       │
  StreamWriter ──► [ring buffer] ──► StreamReader
                                           │
                                      FileDesc (uart driver) ← handle lives here
                                           │
                                      [UART hardware]
```

The `Stream` can be a direct connection to a device?
Do you need a stream for a direct connection?
Or will there always be a need for a buffer.
