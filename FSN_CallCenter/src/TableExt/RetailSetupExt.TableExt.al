tableextension 50050 "FSN RetailSetupCC" extends "LSC Retail Setup"
{
    fields
    {
        field(50100; "FSN Is Local Receipt"; Boolean)
        {
            DataClassification = ToBeClassified;
        }
        field(50110; "FSN Last Slipt No."; Code[20])
        {
            DataClassification = ToBeClassified;
        }
    }
}