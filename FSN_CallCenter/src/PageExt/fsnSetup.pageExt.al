pageextension 50036 "FSN Delivery Extend" extends "FSN Fasani Setup"
{
    layout
    {
        addafter("Day for Exch. Block/Req.")
        {
            field("Delivery < $9.99"; "Delivery < $9.99")
            {
                Caption = 'Delivery < $9.99';
                ApplicationArea = All;
            }
            field("Delivery < $39.99"; "Delivery < $39.99")
            {
                Caption = 'Delivery < $39.99';
                ApplicationArea = All;
            }
            field("C807 Delivery"; "C807 Delivery")
            {
                Caption = 'C807 Delivery';
                ApplicationArea = All;
            }
            field("Delivery < $19.99"; "Delivery < $19.99")
            {
                Caption = 'Delivery < $19.99';
                ApplicationArea = All;
            }
            field("Delivery < $29.99"; "Delivery < $29.99")
            {
                Caption = 'Delivery < $29.99';
                ApplicationArea = All;
            }
        }
    }
}