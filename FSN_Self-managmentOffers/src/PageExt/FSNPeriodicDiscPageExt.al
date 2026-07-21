pageextension 50087 "FSN Periodic Disc. Table Ext" extends "LSC Discount Offer"
{
    layout
    {
        addafter("Price Group Validation")
        {
            field("FSN Máximo para Facturar"; Rec."FSN Max. para Facturar")
            {
                ApplicationArea = All;
            }
        }

        addafter("FSN Máximo para Facturar")
        {
            field("FSN Type MAx. Offer"; Rec."FSN Type Val. Offer")
            {
                ApplicationArea = All;
                Caption = 'FSN Tipo Max. Offer :.';

                trigger OnValidate()
                var
                    myInt: Integer;
                begin
                    if Rec."FSN Type Val. Offer" <> Rec."FSN Type Val. Offer"::None then
                        ValEdit(true)
                    else
                        ValEdit(false);
                end;
            }
        }

        addafter("FSN Type MAx. Offer")
        {
            field("FSN Monto Descuento/compra"; Rec."FSN Amount Discont/Purchase")
            {
                ApplicationArea = All;
                Editable = EditMaxOffer;
                Caption = 'FSN Monto Descuento/compra $ :.';

            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
        EditMaxOffer: boolean;
        EditMaxFacturar: boolean;

    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        if Rec."FSN Type Val. Offer" <> Rec."FSN Type Val. Offer"::None then
            ValEdit(true)
        else
            ValEdit(false);
    end;

    procedure ValEdit(Vis: Boolean)
    var
        myInt: Integer;
    begin
        EditMaxOffer := Vis;
    end;
}