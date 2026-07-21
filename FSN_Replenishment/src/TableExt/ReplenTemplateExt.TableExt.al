tableextension 50040 "FSN ReplenJrnlTemplate" extends "LSC Replen. Template"
{
    fields
    {
        field(50000; "FSN Consolidate No."; Code[30])
        {
            DataClassification = ToBeClassified;
        }
        field(60010; "Associated Credit Memo"; Boolean)
        {
            Caption = 'Associated Credit Memo';
            DataClassification = ToBeClassified;
        }
    }
    var
        Text001: Label 'DEFAULT';
}