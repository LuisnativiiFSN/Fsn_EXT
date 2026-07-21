tableextension 50131 "FSN Return Shipment Header" extends "Return Shipment Header"
{
    fields
    {
        field(60000; "FSNVendor Order No."; Code[35])
        {
            Caption = 'FSN Vendor Order No.';
            DataClassification = ToBeClassified;
        }
    }
}
