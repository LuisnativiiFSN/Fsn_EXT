pageextension 50151 "FSN Bank Acc. Reconciliation" extends "Bank Acc. Reconciliation"
{
    actions
    {
        addafter(Post)
        {
            action(FSNPostAndPrint)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'FSN P&ost&Print';
                Image = PostOrder;
                Promoted = true;
                PromotedCategory = Category6;
                PromotedIsBig = true;
                ShortCutKey = 'F9';
                ToolTip = 'Finalize the document or journal by posting the amounts and quantities to the related accounts in your company books.';
                trigger OnAction()
                var
                    ReportSelections: Record "Report Selections";
                begin
                    ReportSelections.PrintReport(ReportSelections.Usage::"B.Recon.Test", Rec);
                    CODEUNIT.Run(CODEUNIT::"Bank Acc. Recon. Post (Yes/No)", Rec);
                end;
            }
        }
    }
}