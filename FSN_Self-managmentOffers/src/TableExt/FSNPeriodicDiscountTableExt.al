tableextension 50061 "FSN Periodic Disc. Table Ext" extends "LSC Periodic Discount"
{
    fields
    {
        field(50100; "FSN Max. para Facturar"; Integer)
        {
            DataClassification = ToBeClassified;
        }

        field(50200; "FSN Type Val. Offer"; Enum "FSN Type MAx. Offer")
        {
            DataClassification = ToBeClassified;
        }

        field(50300; "FSN Amount Discont/Purchase"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}