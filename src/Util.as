// c 2024-07-14
// m 2024-07-14

string Int64ToHex(const int64 i, const bool pre = false) {
    return (pre ? "0x" : "") + Text::Format("%llX", i);
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
