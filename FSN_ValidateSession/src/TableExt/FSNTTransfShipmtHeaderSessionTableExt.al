tableextension 50118 "FSN Transfer Shipment Header" extends "Transfer Shipment Header"
{
    fields
    {
        field(50500; "FSN User"; Code[20])
        {
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}