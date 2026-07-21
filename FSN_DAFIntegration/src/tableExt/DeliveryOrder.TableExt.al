tableextension 50018 "FSN Delivery Order Ext" extends "LSC Delivery Order"
{
    fields
    {
        field(50101; "FSN Cambio Efectivo"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}