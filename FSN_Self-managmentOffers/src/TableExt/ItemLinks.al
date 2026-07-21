tableextension 50063 "FSN Item Status Link" extends "LSC Item Status Link"
{
    fields
    {
        // Add changes to table fields here
        field(50100; "FSN Maximum billing"; Integer)
        {
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}