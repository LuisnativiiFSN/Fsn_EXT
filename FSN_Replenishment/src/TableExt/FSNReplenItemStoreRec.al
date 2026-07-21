tableextension 50080 "FSN Replen. Item Store Rec" extends "LSC Replen. Item Store Rec"
{
    fields
    {
        field(50013; "FSN Previous Minimum"; Integer)
        {
            DataClassification = ToBeClassified;
        }
        field(50014; "FSN Previous Maximum"; Integer)
        {
            DataClassification = ToBeClassified;
        }
        field(50015; "FSN Text"; Text[50])
        {
            DataClassification = ToBeClassified;
        }
        field(50016; "FSN Date Update"; Date)
        {
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}