// c 2024-07-14
// m 2024-07-15

namespace Bitmaps {
    shared enum Compression {
        BI_RGB            = 0,
        BI_RLE8           = 1,
        BI_RLE4           = 2,
        BI_BITFIELDS      = 3,
        BI_JPEG           = 4,
        BI_PNG            = 5,
        BI_ALPHABITFIELDS = 6,
        BI_CMYK           = 11,
        BI_CMYKRLE8       = 12,
        BI_CMYKRLE4       = 13
    }

    shared enum InfoHeader {
        NONE             = 0,
        BITMAPCOREHEADER = 12,
        BITMAPINFOHEADER = 40,
        BITMAPV4HEADER   = 108,
        BITMAPV5HEADER   = 124
    }

    shared class Bitmap {
        private uint minDataSize = 4;
        private uint minFileSize = 30;

        private   uint offsetSignature = 0x0;
        private   uint offsetFileSize  = offsetSignature + 0x2;
        protected uint offsetDataLoc   = offsetFileSize  + 0x8;  // skip 4 bytes reserved
        protected uint offsetInfoSize  = offsetDataLoc   + 0x4;

        private   uint   dataOffset;
        protected uint   fileSize;
        private   string signature;
        private   uint64 size;

        private InfoHeader _infoHeaderType;
        InfoHeader get_infoHeaderType() {
            return _infoHeaderType;
        }
        private void set_infoHeaderType(InfoHeader type) {
            _infoHeaderType = type;
        }

        MemoryBuffer@ buf;
        MemoryBuffer@ data;

        Bitmap() { }
        Bitmap(MemoryBuffer@ buf) {
            if (buf is null)
                throw("buffer null");

            @this.buf = buf;

            size = buf.GetSize();
            if (size < minFileSize)
                throw("buffer too small: " + size);

            buf.Seek(offsetSignature);
            signature = buf.ReadString(2);
            if (signature != "BM")
                throw("invalid signature: " + signature);

            buf.Seek(offsetFileSize);
            fileSize = buf.ReadUInt32();
            if (fileSize != size)
                throw("fileSize does not match buffer size: " + fileSize + " != " + size);

            buf.Seek(offsetDataLoc);
            dataOffset = buf.ReadUInt32();
            if (dataOffset < minFileSize - minDataSize || dataOffset > fileSize - minDataSize)
                throw("invalid dataOffset: " + dataOffset);

            buf.Seek(offsetInfoSize);
            const uint infoHeaderSize = buf.ReadUInt32();
            const uint[] validInfoHeaderSizes = { 12, 40, 108, 124 };
            if (validInfoHeaderSizes.Find(infoHeaderSize) == -1)
                throw("invalid infoHeaderSize: " + infoHeaderSize);
            infoHeaderType = InfoHeader(infoHeaderSize);
        }

        MemoryBuffer@ ToBuffer() {
            MemoryBuffer@ buf = MemoryBuffer(size);

            buf.Seek(offsetSignature);
            buf.Write(signature);

            buf.Seek(offsetFileSize);
            buf.Write(fileSize);

            buf.Seek(offsetDataLoc);
            buf.Write(dataOffset);

            return buf;
        }

        Json::Value@ ToJson() {
            Json::Value@ json = Json::Object();

            json["signature"]      = signature;
            json["fileSize"]       = fileSize;
            json["dataOffset"]     = dataOffset;
            json["infoHeaderSize"] = uint(infoHeaderType);

            return json;
        }

        string ToString() final {
            return Json::Write(ToJson());
        }
    }

    shared class BitmapCoreHeader : Bitmap {
        private uint offsetWidth    = offsetInfoSize + 0x4;
        private uint offsetHeight   = offsetWidth    + 0x2;
        private uint offsetPlanes   = offsetHeight   + 0x2;
        private uint offsetBitCount = offsetPlanes   + 0x2;

        uint16 bitCount;
        uint16 height;
        uint16 width;

        BitmapCoreHeader() { super(); }
        BitmapCoreHeader(MemoryBuffer@ buf) {
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

            buf.Seek(offsetDataLoc);
            @data = buf.ReadBuffer(fileSize - offsetDataLoc);
            const uint64 dataSize = data.GetSize();
            if (dataSize == 0)
                throw("data is empty");
            if (dataSize % 4 != 0)
                throw("data not aligned to 4 bytes");
        }

        MemoryBuffer@ ToBuffer() override {
            MemoryBuffer@ buf = Bitmap::ToBuffer();

            buf.Seek(offsetInfoSize);
            buf.Write(uint(infoHeaderType));

            buf.Seek(offsetWidth);
            buf.Write(width);

            buf.Seek(offsetHeight);
            buf.Write(height);

            buf.Seek(offsetPlanes);
            buf.Write(uint16(1));

            buf.Seek(offsetBitCount);
            buf.Write(bitCount);

            buf.Seek(offsetDataLoc);
            buf.WriteFromBuffer(data, data.GetSize());

            return buf;
        }

        Json::Value@ ToJson() override {
            Json::Value@ json = Bitmap::ToJson();

            json["bitCount"] = bitCount;
            json["height"]   = height;
            json["width"]    = width;

            return json;
        }
    }

    shared class BitmapV1Header : Bitmap {
        private uint offsetWidth       = offsetInfoSize    + 0x4;
        private uint offsetHeight      = offsetWidth       + 0x4;
        private uint offsetPlanes      = offsetHeight      + 0x4;
        private uint offsetBitCount    = offsetPlanes      + 0x2;
        private uint offsetCompression = offsetBitCount    + 0x2;
        private uint offsetImageSize   = offsetCompression + 0x4;

        uint16      bitCount;
        Compression compression;
        int         height;
        uint        imageSize;
        int         width;

        BitmapV1Header() { super(); }
        BitmapV1Header(MemoryBuffer@ buf) {
            super(buf);

            if (infoHeaderType != InfoHeader::BITMAPINFOHEADER)
                throw("bitmap does not have a BITMAPINFOHEADER");

            buf.Seek(offsetWidth);
            width = buf.ReadInt32();
            if (width < 1)
                throw("width < 1: " + width);

            buf.Seek(offsetHeight);
            height = buf.ReadInt32();
            if (height < 1)
                throw("height < 1: " + height);

            buf.Seek(offsetPlanes);
            const uint16 planes = buf.ReadUInt16();
            if (planes != 1)
                throw("planes is not 1: " + planes);

            buf.Seek(offsetBitCount);
            bitCount = buf.ReadUInt16();
            if (bitCount == 0)
                throw("bitCount is 0");

            buf.Seek(offsetCompression);
            const uint comp = buf.ReadUInt32();
            const uint[] validCompressionTypes = { 0, 1, 2, 3, 4, 5, 6, 11, 12, 13 };
            if (validCompressionTypes.Find(comp) == -1)
                throw("invalid compression type: " + comp);
            compression = Compression(comp);
        }

        MemoryBuffer@ ToBuffer() override {
            MemoryBuffer@ buf = Bitmap::ToBuffer();

            ;

            return buf;
        }

        Json::Value@ ToJson() override {
            Json::Value@ json = Bitmap::ToJson();

            json["bitCount"]    = bitCount;
            json["compression"] = uint(compression);
            json["height"]      = height;
            json["imageSize"]   = imageSize;
            json["width"]       = width;

            return json;
        }
    }
}
