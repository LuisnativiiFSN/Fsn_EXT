pageextension 50141 MyExtension extends "LSC Store Card"
{
    layout
    {
        addafter(General)
        {
            group("FASANI")
            {
                Caption = 'FASANI';

                field("FSN minimum day"; "FSN minimum day")
                {
                    Caption = 'Dia Minimo';
                    ApplicationArea = all;
                }
                field("FSN maximum day"; "FSN maximum day")
                {
                    Caption = 'Dia Maximo';
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                    end;
                }
                field("FSN Grupo No. Stock Level"; "FSN Grupo No. Stock Level")
                {
                    Caption = 'FSN Grupo No. Stock Level';
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin

                    end;
                }
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}