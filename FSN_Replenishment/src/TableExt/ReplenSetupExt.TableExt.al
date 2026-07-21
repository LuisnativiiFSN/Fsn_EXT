tableextension 50041 "FSN ReplenSetupExt" extends "LSC Replen. Setup"
{
    fields
    {
        field(50000; "FSN Consolidate Serie No."; Code[10])
        {
            DataClassification = ToBeClassified;
            TableRelation = "No. Series".Code;
        }
        field(50010; "FSN Approach Multiple %"; Decimal)
        {
            MaxValue = 100;
            MinValue = 0;
            DataClassification = ToBeClassified;
        }
        field(50020; "FSN Approach Adjustment Type"; Option)
        {
            OptionMembers = LowerOrHigher,Higher,Lower;
            DataClassification = ToBeClassified;
        }
        field(50030; "FSN Transfer Consolidate No."; Code[20])
        {
            DataClassification = ToBeClassified;
            TableRelation = "No. Series".Code;
        }
    }
}