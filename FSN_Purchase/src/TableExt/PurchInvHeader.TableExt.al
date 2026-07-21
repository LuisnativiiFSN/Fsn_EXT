/// <summary>
/// TableExtension Purch. Inv. header Ext (ID 50049) extends Record Purch. Inv. Header.
/// </summary>
tableextension 50052 "Purch. Inv. header Ext" extends "Purch. Inv. Header"
{
    fields
    {
        field(201; "SubTotal"; Decimal)
        { }
        field(202; "Tax"; Decimal)
        { }
        field(203; "Total"; Decimal)
        { }
    }
}