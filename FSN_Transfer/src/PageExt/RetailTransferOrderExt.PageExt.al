pageextension 50048 "FSN Retail Transfer OrderExt" extends "LSC Retail Transfer Order"
{
    layout
    {
        addafter("Customer Order ID")
        {
            field("ExternalDocument No."; "External Document No.")
            {
                ApplicationArea = All;
                Editable = false;
                Caption = 'Nº documento externo';
                ToolTip = 'Nº documento externo';
            }
        }
    }

    actions
    {
        addafter("&Print")
        {
            action("FSN Print")
            {
                ApplicationArea = All;
                Caption = 'FSN Print';
                Promoted = true;
                Image = Print;
                PromotedCategory = Category7;
                trigger OnAction()
                var
                    Transfer_l: Record "Transfer Header";
                begin
                    if Rec.Status = Rec.Status::Open then
                        exit;
                    Transfer_l.Reset();
                    Transfer_l.SetRange("No.", Rec."No.");
                    Report.Run(REPORT::"FSN Remission Transfer", true, true, Transfer_l);
                end;
            }
        }
        addafter("P&osting")
        {
            action("FSN Scanner")
            {
                ApplicationArea = All;
                Caption = 'FSN Scanner';
                Ellipsis = true;
                Image = SendConfirmation;
                Promoted = true;
                PromotedCategory = Category5;
                PromotedIsBig = true;
                trigger OnAction()
                var
                    FSNScanner: Page "FSN Transfer Scanner";
                begin
                    if Status = Status::Open then begin
                        clear(FSNScanner);
                        FSNScanner.SetPurchOrderNo(Rec."No.");
                        FSNScanner.RunModal();
                    end;
                end;
            }
        }
    }



}
