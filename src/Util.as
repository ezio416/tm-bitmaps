// c 2024-07-14
// m 2024-07-15

const string GREEN = "\\$0F0";
const string RED   = "\\$F00";

string Int64ToHex(const int64 i, const bool pre = false) {
    return (pre ? "0x" : "") + Text::Format("%llX", i);
}

string JsonPretty(Json::Value@ json) {
    return Json::Write(json).Replace("{", "{\n").Replace(",", ",\n").Replace("}", "\n}");
}

string UInt8ToBin(const uint8 u, const bool pre = false) {
    string ret = pre ? "0b" : "";

    for (int i = 7; i >= 0; i--)
        ret += tostring(u >> i & 1);

    return ret;
}

string UInt8ToChar(const uint8 n) {
    string ret = "A";
    ret[0] = n;
    return ret;
}

string Zpad(const string &in hex, const uint length = 2) {
    if (uint(hex.Length) >= length)
        return hex;

    string res;

    for (uint i = hex.Length; i < length; i++)
        res += "0";

    return res + hex;
}

namespace UI {
    void ViewMemoryBuffer(MemoryBuffer@ buf, UI::Font@ font = null) {
        const uint64 size = buf.GetSize();

        if (font !is null)
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

        if (font !is null)
            UI::PopFont();

        UI::NewLine();
    }
}
