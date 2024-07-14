// c 2024-07-14
// m 2024-07-14

enum Compression {
    BI_RGB,
    BI_RLE8,
    BI_RLE4
}

enum InfoHeader {
    BITMAPCOREHEADER = 12,
    BITMAPINFOHEADER = 40,
    BITMAPV4HEADER   = 108,
    BITMAPV5HEADER   = 124
}

class Bitmap {
    private   uint offsetSig1     = 0x0;
    private   uint offsetSig2     = 0x1;
    private   uint offsetFileSize = 0x2;
    private   uint offsetDataSize = 0xA;
    protected uint offsetInfoSize = 0xE;

    private   uint       dataOffset;
    private   uint       fileHeaderSize       = 14;
    private   uint       fileSize;
    protected InfoHeader infoHeaderType;
    protected uint       minDataSize          = 4;
    private   uint       minFileSize          = 30;
    private   string     signature;
    private   uint64     size;
    private   uint[]     validInfoHeaderSizes = { 12, 40, 108, 124 };

    Bitmap() { }
    Bitmap(MemoryBuffer@ buf) {
        if (buf is null)
            throw("buffer null");

        size = buf.GetSize();
        if (size < minFileSize)
            throw("buffer too small: " + size);

        buf.Seek(offsetSig1);
        signature += UInt8ToChar(buf.ReadUInt8());
        buf.Seek(offsetSig2);
        signature += UInt8ToChar(buf.ReadUInt8());
        if (signature != "BM")
            throw("invalid signature: " + signature);

        buf.Seek(offsetFileSize);
        fileSize = buf.ReadUInt32();
        if (fileSize != size)
            throw("fileSize does not match buffer size: " + fileSize + " != " + size);

        buf.Seek(offsetDataSize);
        dataOffset = buf.ReadUInt32();
        if (dataOffset < minFileSize - minDataSize || dataOffset > fileSize - minDataSize)
            throw("invalid dataOffset: " + dataOffset);

        buf.Seek(offsetInfoSize);
        const uint infoHeaderSize = buf.ReadUInt32();
        if (validInfoHeaderSizes.Find(infoHeaderSize) == -1)
            throw("invalid infoHeaderSize: " + infoHeaderSize);
        infoHeaderType = InfoHeader(infoHeaderSize);
    }
}

class BitmapWithCoreHeader : Bitmap {
    private uint offsetWidth    = offsetInfoSize + 0x4;
    private uint offsetHeight   = offsetInfoSize + 0x6;
    private uint offsetPlanes   = offsetInfoSize + 0x8;
    private uint offsetBitCount = offsetInfoSize + 0xA;

    uint16 bitCount;
    uint16 height;
    uint16 width;

    BitmapWithCoreHeader() { super(); }
    BitmapWithCoreHeader(MemoryBuffer@ buf) {
        super(buf);

        if (infoHeaderType != InfoHeader::BITMAPCOREHEADER)
            throw("bitmap does not have a BITMAPCOREHEADER");

        buf.Seek(offsetWidth);
        width = buf.ReadUInt16();
        if (width == 0)
            throw("width is 0");

        buf.Seek(offsetHeight);
        height = buf.ReadUInt16();
        if (height == 0)
            throw("height is 0");

        buf.Seek(offsetPlanes);
        const uint16 planes = buf.ReadUInt16();
        if (planes != 1)
            throw("planes is not 1: " + planes);

        buf.Seek(offsetBitCount);
        bitCount = buf.ReadUInt16();
        const uint16[] validBitCounts = { 1, 4, 8, 24 };
        if (validBitCounts.Find(bitCount) == -1)
            throw("invalid bit count: " + bitCount);
    }
}
