// c 2024-07-15
// m 2024-07-15

namespace Bitmaps {
    InfoHeader GetHeaderType(MemoryBuffer@ buf) {
        try {
            return Bitmap(buf).infoHeaderType;
        } catch {
            return InfoHeader::NONE;
        }
    }
}
