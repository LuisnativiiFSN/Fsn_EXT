pageextension 50059 "FSN VAT Ledger" extends "VAT Ledger"
{
    layout
    {
        addafter("Document No.")
        {
            field("DTE AuthNumber"; "DTE AuthNumber")
            {
                ApplicationArea = All;
                Caption = 'DTE AuthNumber';
                ToolTip = 'DTE AuthNumber';
            }
            field("DTE Invoice"; "DTE Invoice")
            {
                ApplicationArea = All;
                Caption = 'DTE Invoice';
                ToolTip = 'DTE Invoice';
            }
            field("Signature Validation"; "Signature Validation")
            {
                ApplicationArea = All;
                Caption = 'Signature Validation';
                ToolTip = 'Signature Validation';
            }
            field(Perception; Rec.Perception)
            {
                ApplicationArea = All;
                CaptionML = ENU = 'Perception', ESM = 'Percepción';
            }

        }
        addafter("Document Date")
        {
            field("Posting Date"; Rec."Posting Date")
            {
                ApplicationArea = All;
            }
        }
        //JH27082024-1 Se agrega el campo terminal para mostrar en las ventas
        addafter(Establishment)
        {
            field(Terminal; Terminal)
            {
                ApplicationArea = All;
                Caption = 'Terminal';
                ToolTip = 'Terminal';
            }
        }
    }
    actions
    {
        addbefore(GenLedger)
        {
            action(GenerateVATLedger)
            {
                ApplicationArea = All;
                Image = GeneralLedger;
                Promoted = true;
                PromotedCategory = Process;
                Caption = 'FSN Generate VAT Ledger';
                ToolTip = 'Generate VAT Ledger';
                PromotedIsBig = true;
                trigger OnAction()
                begin
                    FSNVATLedger.RunModal();
                    Clear(FSNVATLedger);
                end;
            }
        }
    }

    var
        FSNVATLedger: Report "FSN Generate Legal Ledger";
        currType: Option;
}