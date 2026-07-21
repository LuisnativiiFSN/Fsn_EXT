pageextension 50149 "FSN Retail Receiving List " extends "LSC Retail Receiving List"
{
    layout
    {
        addAfter("Store No.")
        {
            field("FSN Status"; Rec."FSN Status")
            {
                Caption = 'FSN Status';
                Editable = false;
                StyleExpr = StyleStatusText;
            }
        }

        addAfter("FSN Status")
        {
            //PurchaseV66-3 add Field
            field("DTE Invoice"; Rec."DTE Invoice")
            {
                Editable = false;
            }
            field("FSN Message Process"; Rec."FSN Message Process")
            {
                Editable = false;
                StyleExpr = 'Attention';
            }
            //PurchaseV66-1 Add Field
            field("FSN Authorized Reception"; Rec."FSN Authorized Reception")
            {
                Editable = false;
            }
            //PurchaseV70 add Field
            field("FSN Shared with EBS"; Rec."FSN Shared with EBS")
            {
                Editable = false;
            }
            //PurchaseV66-2 Add Field
            field("FSN Date Authorized"; Rec."FSN Date Authorized")
            {
                Editable = false;
            }
        }




    }

    actions
    {

        addfirst(Processing)
        {
            action(FSNCompartirEBS)
            {
                ApplicationArea = all;
                Caption = 'FSN Compartir Con EBS';
                Image = ShipmentLines;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ShortCutKey = 'Shift+F9';
                ToolTip = 'Compartir las lineas de todas las recepciones del mismo pedido con EBS';
                trigger OnAction()
                var
                    ExtPurch: Codeunit "FSN External Purch. Manager";
                begin
                    ExtPurch.SendExtPurchLineLotes(Rec);
                end;
            }
            /*action(CreatePurchaseOrderAlternative)
            {
                ApplicationArea = all;
                Caption = 'Crear Pedido Alternativo';
                Image = NewPurchaseInvoice;
                Promoted = true;
                PromotedCategory = Process;
                ShortCutKey = 'Shift+F8';
                PromotedIsBig = true;
                ToolTip = 'Crear un pedido alternativo de las lineas no recepcionadas';
                trigger OnAction()
                var
                    Vend: Record Vendor;
                    FSNExternalPurchMgr: Codeunit "FSN External Purch. Manager";
                begin
                    if Rec."FSN Authorized Reception" and Rec."FSN Shared with EBS" then begin
                        if PAGE.RunModal(PAGE::"Vendor List", Vend) = ACTION::LookupOK then begin
                            FSNExternalPurchMgr.CreatePurchaseOrderAlternative(Vend, Rec);
                        end;
                    end else
                        Error('Si la Recepción %1 no ha sido autorizada y compartida con EBS, no se puede crear un pedido alternativo.', Rec."No.");
                end;
            }*/

        }

    }

    var
        myInt: Integer;
        StyleStatusText: Text;
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;

    trigger OnAfterGetRecord()
    begin
        ValStyle;
    end;

    trigger OnOpenPage()
    begin
        ValStyle;
    end;

    procedure ValStyle()
    begin
        if Rec."FSN Status" = Rec."FSN Status"::AplicandoAutomatico then
            StyleStatusText := Format(StyleStatus::StrongAccent)
        else
            StyleStatusText := Format(StyleStatus::None)
    end;
}
