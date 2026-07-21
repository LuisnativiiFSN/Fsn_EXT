tableextension 50017 "FSN Delivery Driver Trip Ext" extends "LSC Delivery Driver Trip"
{
    fields
    {
        field(50101; "FSN DAF Trip No."; integer)
        {
            DataClassification = ToBeClassified;
        }
        field(50102; "FSN Functionality Type"; Option)
        {
            OptionCaption = 'Manual, Automatic';
            OptionMembers = Manual,Automatic;
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}