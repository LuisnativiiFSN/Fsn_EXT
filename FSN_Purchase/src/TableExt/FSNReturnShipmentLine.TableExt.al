tableextension 50132 "FSN Return Shipment Line" extends "Return Shipment Line"
{
    fields
    {
        field(60000; "Vendor Order No."; Code[35])
        {
            Caption = 'Vendor Order No.';
            DataClassification = ToBeClassified;
        }
    }
}
