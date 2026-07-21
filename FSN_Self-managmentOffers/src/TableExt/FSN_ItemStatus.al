tableextension 50062 "FSN Item Status" extends "LSC Item Status"
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