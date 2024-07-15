// c 2024-07-13
// m 2024-07-15

BitmapCoreHeader@ bmp;
UI::Font@         font;
const string      GREEN = "\\$0F0";
const string      RED   = "\\$F00";
const string      title = "\\$FFF" + Icons::FileImageO + "\\$G Bitmaps";

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Show/hide with game UI"]
bool S_HideWithGame = true;

[Setting category="General" name="Show/hide with Openplanet UI"]
bool S_HideWithOP = false;

void Main() {
    @font = UI::LoadFont("DroidSansMono.ttf");

    IO::FileSource file("test_images/bmp.bmp");
    @bmp = BitmapCoreHeader(file.Read(file.Size()));
}

void Render() {
    if (false
        || !S_Enabled
        || (S_HideWithGame && !UI::IsGameUIVisible())
        || (S_HideWithOP && !UI::IsOverlayShown())
        || bmp is null
    )
        return;

    if (UI::Begin(title, S_Enabled, UI::WindowFlags::None)) {
        UI::Text(tostring(bmp));
    }
    UI::End();
}

void RenderMenu() {
    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void View1BitBitmap(MemoryBuffer@ buf) {
    UI::PushFont(font);

    UI::Text("Header");

    const uint64 headerSize = 14;
    for (uint64 i = 0; i < headerSize; i++) {
        buf.Seek(i);

        const uint8  val = buf.ReadUInt8();
        const string hex = Zpad(Int64ToHex(val));

        UI::Text((val > 0 ? GREEN : RED) + hex);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(tostring(val));
            UI::Text(UInt8ToChar(val));
            UI::Text(UInt8ToBin(val, true));
            UI::EndTooltip();
        }

        UI::SameLine();

        if ((i + 1) % 4 == 0) {
            UI::Text(" ");
            UI::SameLine();
        }

        if ((i + 1) % 16 == 0)
            UI::NewLine();
    }

    UI::NewLine();

    buf.Seek(0x0);
    const string signature = "Signature:        " + UInt8ToChar(buf.ReadUInt8());
    buf.Seek(0x1);
    UI::Text(signature + UInt8ToChar(buf.ReadUInt8()));

    buf.Seek(0x2);
    UI::Text("FileSize:         " + tostring(buf.ReadUInt32()) + " b");

    buf.Seek(0x6);
    UI::Text("reserved:         " + tostring(buf.ReadUInt32()));

    buf.Seek(0xA);
    const uint pixelDataStart = buf.ReadUInt32();
    UI::Text("DataOffset:       " + tostring(pixelDataStart) + " b");

    UI::Separator();

    UI::Text("InfoHeader");

    const uint64 infoHeaderStart = 0xE;
    buf.Seek(infoHeaderStart);
    const uint infoHeaderSize = buf.ReadUInt32();
    for (uint64 i = infoHeaderStart; i < infoHeaderStart + infoHeaderSize; i++) {
        buf.Seek(i);

        const uint8  val = buf.ReadUInt8();
        const string hex = Zpad(Int64ToHex(val));

        UI::Text((val > 0 ? GREEN : RED) + hex);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(tostring(val));
            UI::Text(UInt8ToChar(val));
            UI::Text(UInt8ToBin(val, true));
            UI::EndTooltip();
        }

        UI::SameLine();

        if ((i + 3) % 4 == 0) {
            UI::Text(" ");
            UI::SameLine();
        }

        if ((i + 1) % 16 == headerSize)
            UI::NewLine();
    }

    UI::NewLine();

    UI::Text("Size:             " + tostring(infoHeaderSize) + " b");

    buf.Seek(0x12);
    const uint width = buf.ReadUInt32();
    UI::Text("Width:            " + tostring(width) + " px");

    buf.Seek(0x16);
    const uint height = buf.ReadUInt32();
    UI::Text("Height:           " + tostring(height) + " px");

    buf.Seek(0x1A);
    UI::Text("Planes:           " + tostring(buf.ReadUInt16()));

    buf.Seek(0x1C);
    const uint16 bpp = buf.ReadUInt16();
    if (bpp != 1)
        throw("not a 1 bit per pixel bitmap");
    UI::Text("Bits Per Pixel:   " + tostring(bpp));

    buf.Seek(0x1E);
    const uint compression = buf.ReadUInt32();
    UI::Text("Compression:      " + (compression == 0 ? "BI_RGB" : compression == 1 ? "BI_RLE8" : "BI_RLE4"));

    buf.Seek(0x22);
    const uint imageSize = buf.ReadUInt32();
    UI::Text("ImageSize:        " + tostring(imageSize));

    buf.Seek(0x26);
    UI::Text("XpixelsPerM:      " + tostring(buf.ReadUInt32()));

    buf.Seek(0x2A);
    UI::Text("YpixelsPerM:      " + tostring(buf.ReadUInt32()));

    buf.Seek(0x2E);
    const uint numColors = buf.ReadUInt32();
    UI::Text("Colors Used:      " + tostring(numColors));

    buf.Seek(0x32);
    UI::Text("Important Colors: " + tostring(buf.ReadUInt32()));

    UI::Separator();

    UI::Text("ColorTable");

    const uint64 colorTableStart = 0x36;
    buf.Seek(colorTableStart);
    const uint64 colorTableSize = numColors * 4;
    for (uint64 i = colorTableStart; i < colorTableStart + colorTableSize; i++) {
        buf.Seek(i);

        const uint8  val = buf.ReadUInt8();
        const string hex = Zpad(Int64ToHex(val));

        UI::Text((val > 0 ? GREEN : RED) + hex);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(tostring(val));
            UI::Text(UInt8ToChar(val));
            UI::Text(UInt8ToBin(val, true));
            UI::EndTooltip();
        }

        UI::SameLine();

        if ((i + 3) % 4 == 0) {
            UI::Text(" ");
            UI::SameLine();
        }

        if ((i + 1) % 16 == headerSize)
            UI::NewLine();
    }

    ;

    UI::Separator();

    UI::Text("Pixel Data");

    buf.Seek(pixelDataStart);
    for (uint64 i = pixelDataStart; i < pixelDataStart + imageSize; i++) {
        buf.Seek(i);

        const uint8  val = buf.ReadUInt8();
        const string hex = Zpad(Int64ToHex(val));

        UI::Text((val > 0 ? GREEN : RED) + hex);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(tostring(val));
            UI::Text(UInt8ToChar(val));
            UI::Text(UInt8ToBin(val, true));
            UI::EndTooltip();
        }

        UI::SameLine();

        if ((i + 3) % 4 == 0) {
            UI::Text(" ");
            UI::SameLine();
        }

        if ((i + 1) % 16 == headerSize)
            UI::NewLine();
    }

    UI::Separator();

    UI::Text("Image");

    string[] data;

    for (uint64 i = pixelDataStart; i < pixelDataStart + imageSize; i += 4) {
        buf.Seek(i);

        const uint8 val = buf.ReadUInt8();
        string num;
        for (int j = 7; j >= 0; j--) {
            const uint8 n = val >> j & 1;
            num += (n == 1 ? GREEN : RED) + tostring(n);
        }
        data.InsertLast(num);
    }

    data.Reverse();

    for (uint i = 0; i < data.Length; i++)
        UI::Text(data[i]);

    UI::PopFont();
}

void MemoryBufferViewer(MemoryBuffer@ buf) {
    const uint64 size = buf.GetSize();

    UI::PushFont(font);

    for (uint i = 0; i < size; i++) {
        buf.Seek(i);

        const uint8  val = buf.ReadUInt8();
        const string hex = Zpad(Int64ToHex(val));

        UI::Text((val == 0 ? RED : GREEN) + hex);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(tostring(val));
            UI::Text(UInt8ToChar(val));
            UI::Text(UInt8ToBin(val, true));
            UI::EndTooltip();
        }

        UI::SameLine();

        if ((i + 1) % 4 == 0) {
            UI::Text("");
            UI::SameLine();
        }

        if ((i + 1) % 16 == 0)
            UI::NewLine();
    }

    UI::PopFont();
}
