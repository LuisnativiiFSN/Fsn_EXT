pageextension 50067 "FSN ReplenItemStoreRecExt" extends "LSC Replen. Item Store Rec"
{
    layout
    {
        addbefore(General)
        {
            group("Descriptions")
            {
                field("FSN Division"; "FSN Division")
                {
                    ApplicationArea = All;
                }
                field("FSN Category"; "FSN Category")
                {
                    ApplicationArea = All;
                }
                field("FSN Product Group"; "FSN Product Group")
                {
                    ApplicationArea = All;
                }
                field("FSN Vendor Name"; "FSN Vendor Name")
                {
                    ApplicationArea = All;
                }
            }
        }
        addafter(General)
        {
            group("FASANI")
            {
                Caption = 'FASANI';

                field("Attrib 1 Code"; "FSN Attrib 1 Code")
                {
                    Caption = 'Attrib 1 Code';
                    ApplicationArea = all;
                }
                field("FSN Minimum"; "FSN Minimum")
                {
                    DecimalPlaces = 2;
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("FSN Maximum"; "FSN Maximum")
                {
                    DecimalPlaces = 2;
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("FSN Approach Multiple"; "FSN Approach Multiple")
                {
                    DecimalPlaces = 2;
                    Caption = 'FSN Approach Multiple';
                    ApplicationArea = All;
                }
                field("FSN Purch. Multiple"; "FSN Purch. Multiple")
                {
                    DecimalPlaces = 2;
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("FSN Transfer Multiple"; "FSN Transfer Multiple")
                {
                    DecimalPlaces = 2;
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }

                field("FSN Previous Maximum"; "FSN Previous Maximum")
                {
                    Caption = 'FSN Max Anterior';
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin

                    end;
                }
                field("FSN Previous Minimum"; "FSN Previous Minimum")
                {
                    Caption = 'FSN Min Anterior';
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin

                    end;
                }

                field("FSN Text"; "FSN Text")
                {
                    Caption = 'FSN Texto';
                    ApplicationArea = All;
                    trigger OnValidate()
                    begin

                    end;
                }

                field("FSN Date Update"; "FSN Date Update")
                {
                    Caption = 'FSN Fecha Actualizacion';
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
}