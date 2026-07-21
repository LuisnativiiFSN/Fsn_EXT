tableextension 50116 "FSN Purch. Inv. Header" extends "Purch. Inv. Header"
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