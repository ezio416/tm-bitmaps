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
        protected uint DWORD = 4;  // ULONG
        protected uint LONG  = 4;
        protected uint WORD  = 2;

        private uint minDataSize = 4;
        private uint minFileSize = 30;

        private   uint offsetSignature = 0x0;
        private   uint offsetFileSize  = offsetSignature + WORD;
        private   uint offsetReserved  = offsetFileSize  + DWORD;
        private   uint offsetDataLoc   = offsetReserved  + WORD * 2;
        protected uint offsetInfoSize  = offsetDataLoc   + DWORD;

        protected uint   dataOffset;
        private   uint   fileSize;
        private   string signature;
        private   uint64 size;

        private MemoryBuffer@ _buf;
        MemoryBuffer@ get_buf() { return _buf; }
        private void set_buf(MemoryBuffer@ b) { @_buf = b; }

        private MemoryBuffer@ _data;
        MemoryBuffer@ get_data() { return _data; }
        private void set_data(MemoryBuffer@ d) { @_data = d; }

        private InfoHeader _infoHeaderType;
        InfoHeader get_infoHeaderType() { return _infoHeaderType; }
        private void set_infoHeaderType(InfoHeader i) { _infoHeaderType = i; }

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
                throw("file size does not match buffer size: " + fileSize + " != " + size);

            buf.Seek(offsetDataLoc);
            dataOffset = buf.ReadUInt32();
            if (dataOffset < minFileSize - minDataSize || dataOffset > fileSize - minDataSize)
                throw("invalid data offset: " + dataOffset);

            buf.Seek(offsetInfoSize);
            const uint infoHeaderSize = buf.ReadUInt32();
            const uint[] validInfoHeaderSizes = { 12, 40, 108, 124 };
            if (validInfoHeaderSizes.Find(infoHeaderSize) == -1)
                throw("invalid info header size: " + infoHeaderSize);
            infoHeaderType = InfoHeader(infoHeaderSize);

            buf.Seek(dataOffset);
            @data = buf.ReadBuffer(fileSize - dataOffset);
            const uint64 dataSize = data.GetSize();
            if (dataSize == 0)
                throw("data is empty");
            if (dataSize % 4 != 0)
                throw("data not aligned to 4 bytes");
        }

        MemoryBuffer@ ToBuffer() {
            MemoryBuffer@ buf = MemoryBuffer(size);

            buf.Seek(offsetSignature);

            buf.Write(signature);
            buf.Write(fileSize);
            buf.Write(uint16(0));  // reserved 1
            buf.Write(uint16(0));  // reserved 2
            buf.Write(dataOffset);
            buf.Write(uint(infoHeaderType));

            buf.Seek(dataOffset);
            data.Seek(0x0);
            buf.WriteFromBuffer(data, data.GetSize());

            return buf;
        }

        Json::Value@ ToJson() {
            Json::Value@ json = Json::Object();

            json["signature"]      = signature;
            json["fileSize"]       = fileSize;
            json["dataOffset"]     = dataOffset;
            json["infoHeaderSize"] = uint(infoHeaderType);
            json["dataSize"]       = data !is null ? data.GetSize() : 0;

            return json;
        }

        string ToString() final {
            return Json::Write(ToJson());
        }
    }

    shared class BitmapCoreHeader : Bitmap {
        private uint offsetWidth    = offsetInfoSize + DWORD;
        private uint offsetHeight   = offsetWidth    + WORD;
        private uint offsetPlanes   = offsetHeight   + WORD;
        private uint offsetBitCount = offsetPlanes   + WORD;

        private uint16 _bitCount;
        uint16 get_bitCount() { return _bitCount; }
        private void set_bitCount(uint16 b) { _bitCount = b; }

        private uint16 _height;
        uint16 get_height() { return _height; }
        private void set_height(uint16 h) { _height = h; }

        private uint16 _width;
        uint16 get_width() { return _width; }
        private void set_width(uint16 w) { _width = w; }

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
                throw("invalid bits per pixel: " + bitCount);
        }

        MemoryBuffer@ ToBuffer() override {
            MemoryBuffer@ buf = Bitmap::ToBuffer();

            buf.Seek(offsetWidth);

            buf.Write(width);
            buf.Write(height);
            buf.Write(uint16(1));  // planes
            buf.Write(bitCount);

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
        private uint offsetWidth       = offsetInfoSize    + DWORD;
        private uint offsetHeight      = offsetWidth       + LONG;
        private uint offsetPlanes      = offsetHeight      + LONG;
        private uint offsetBitCount    = offsetPlanes      + WORD;
        private uint offsetCompression = offsetBitCount    + WORD;
        private uint offsetImageSize   = offsetCompression + DWORD;
        private uint offsetXPixelsPerM = offsetImageSize   + DWORD;
        private uint offsetYPixelsPerM = offsetXPixelsPerM + LONG;
        private uint offsetColorsUsed  = offsetYPixelsPerM + LONG;
        private uint offsetColorsImp   = offsetColorsUsed  + DWORD;
        private uint offsetColorTable  = offsetColorsImp   + DWORD;

        private uint16 _bitCount;
        uint16 get_bitCount() { return _bitCount; }
        private void set_bitCount(uint16 b) { _bitCount = b; }

        private uint _colorsImportant;
        uint get_colorsImportant() { return _colorsImportant; }
        private void set_colorsImportant(uint c) { _colorsImportant = c; }

        private uint _colorsUsed;
        uint get_colorsUsed() { return _colorsUsed; }
        private void set_colorsUsed(uint c) { _colorsUsed = c; }

        private MemoryBuffer@ _colorTable;
        MemoryBuffer@ get_colorTable() { return _colorTable; }
        private void set_colorTable(MemoryBuffer@ c) { @_colorTable = c; }

        private Compression _compression;
        Compression get_compression() { return _compression; }
        private void set_compression(Compression c) { _compression = c; }

        private int _height;
        int get_height() { return _height; }
        private void set_height(int h) { _height = h; }

        private uint _imageSize;
        uint get_imageSize() { return _imageSize; }
        private void set_imageSize(uint i) { _imageSize = i; }

        private int _width;
        int get_width() { return _width; }
        private void set_width(int w) { _width = w; }

        private int _xPixelsPerMeter;
        int get_xPixelsPerMeter() { return _xPixelsPerMeter; }
        private void set_xPixelsPerMeter(int x) { _xPixelsPerMeter = x; }

        private int _yPixelsPerMeter;
        int get_yPixelsPerMeter() { return _yPixelsPerMeter; }
        private void set_yPixelsPerMeter(int y) { _yPixelsPerMeter = y; }

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
                throw("bits per pixel is 0");

            buf.Seek(offsetCompression);
            const uint comp = buf.ReadUInt32();
            const uint[] validCompressionTypes = { 0, 1, 2, 3, 4, 5, 6, 11, 12, 13 };
            if (validCompressionTypes.Find(comp) == -1)
                throw("invalid compression type: " + comp);
            compression = Compression(comp);

            buf.Seek(offsetImageSize);
            imageSize = buf.ReadUInt32();
            const uint64 dataSize = data.GetSize();
            if (imageSize > dataSize)
                throw("image size > data size: " + imageSize + " > " + dataSize);

            buf.Seek(offsetXPixelsPerM);
            xPixelsPerMeter = buf.ReadInt32();
            if (xPixelsPerMeter < 0)
                throw("X pixels per meter < 0: " + xPixelsPerMeter);

            buf.Seek(offsetYPixelsPerM);
            yPixelsPerMeter = buf.ReadInt32();
            if (yPixelsPerMeter < 0)
                throw("Y pixels per meter < 0: " + xPixelsPerMeter);

            buf.Seek(offsetColorsUsed);
            colorsUsed = buf.ReadUInt32();

            buf.Seek(offsetColorsImp);
            colorsImportant = buf.ReadUInt32();

            buf.Seek(offsetColorTable);
            if (compression == Compression::BI_RGB && bitCount <= 8)
                @colorTable = buf.ReadBuffer(DWORD * (colorsUsed > 0 ? colorsUsed : uint64(Math::Pow(2, bitCount))));
            else if (compression == Compression::BI_BITFIELDS)
                @colorTable = buf.ReadBuffer(DWORD * 3);  // color masks
        }

        MemoryBuffer@ ToBuffer() override {
            MemoryBuffer@ buf = Bitmap::ToBuffer();

            buf.Seek(offsetWidth);

            buf.Write(width);
            buf.Write(height);
            buf.Write(uint16(1));  // planes
            buf.Write(bitCount);
            buf.Write(uint(compression));
            buf.Write(imageSize);
            buf.Write(xPixelsPerMeter);
            buf.Write(yPixelsPerMeter);
            buf.Write(colorsUsed);
            buf.Write(colorsImportant);

            if (colorTable !is null) {
                colorTable.Seek(0x0);
                buf.WriteFromBuffer(colorTable, colorTable.GetSize());
            } else {
                for (uint i = offsetColorTable; i < dataOffset; i++)
                    buf.Write(uint(0));
            }

            return buf;
        }

        Json::Value@ ToJson() override {
            Json::Value@ json = Bitmap::ToJson();

            json["bitCount"]        = bitCount;
            json["colorsImportant"] = colorsImportant;
            json["colorTableSize"]  = colorTable !is null ? colorTable.GetSize() : 0;
            json["colorsUsed"]      = colorsUsed;
            json["compression"]     = uint(compression);
            json["height"]          = height;
            json["imageSize"]       = imageSize;
            json["width"]           = width;
            json["xPixelsPerMeter"] = xPixelsPerMeter;
            json["yPixelsPerMeter"] = yPixelsPerMeter;

            return json;
        }
    }
}
