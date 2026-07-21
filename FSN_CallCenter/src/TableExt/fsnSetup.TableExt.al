/// <summary>
/// TableExtension FSN Delivery Extend (ID 50010) extends Record FSN Fasani Setup.
/// </summary>
tableextension 50010 "FSN Delivery Extend" extends "FSN Fasani Setup"
{
    fields
    {
        field(200; "Delivery < $9.99"; Code[20])
        {
            TableRelation = Item;
        }
        field(210; "Delivery < $39.99"; Code[20])
        {
            TableRelation = Item;
        }
        field(230; "C807 Delivery"; Code[20])
        {
            TableRelation = Item;
        }
        field(240; "Delivery < $19.99"; Code[20])
        {
            TableRelation = Item;
        }
        field(250; "Delivery < $29.99"; Code[20])
        {
            TableRelation = Item;
        }
    }
}