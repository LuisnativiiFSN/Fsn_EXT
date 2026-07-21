pageextension 50097 "FSN Whse Receipts List Ext" extends "Warehouse Receipts"
{
    //JHERNANDEZ 1.0.0.14            - C/AL to AL
    layout
    {
        addafter("Posting Date")
        {
            field(Status; Status)
            {
                Caption = 'Estado';
                Editable = false;
                StyleExpr = StyleStatusText;
            }
        }

        addafter("Assigned User ID")
        {
            field("Posting Date19411"; Rec."Posting Date")
            {
                ApplicationArea = All;
            }
            field("Vendor Shipment No.46673"; Rec."Vendor Shipment No.")
            {
                ApplicationArea = All;
            }
        }
    }
    var
        StyleStatusText: Text;
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;

    trigger OnAfterGetRecord()
    begin
        ValStyle;
    end;

    trigger OnOpenPage()
    begin
        ValStyle;
        // Excluir receipts creados por PITS (que comienzan con WR)
        // Esos se muestran en la página "FSN Warehouse Receipts" (50120)
        SetFilter("No.", '<>WR*');
    end;

    procedure ValStyle()
    begin
        if Rec.Status = Rec.Status::AplicandoAutomatico then
            StyleStatusText := Format(StyleStatus::StrongAccent)
        else
            StyleStatusText := Format(StyleStatus::None)
    end;


}