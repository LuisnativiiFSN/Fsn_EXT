pageextension 50096 "FSN Whse Receipt Ext" extends "Warehouse Receipt"
{

    //JHERNANDEZ 1.0.0.14            - C/AL to AL
    layout
    {
        addlast(General)
        {
            field(Status; Status)
            {
                Caption = 'Estado';
                Editable = true;
            }
        }
    }
    actions
    {
        modify(LSCPostAndPrint)
        {
            Enabled = false;
            Visible = false;
            Caption = 'Replaced by LSC action';
        }
        /*modify(LSCPostReceipt)
        {
            Promoted = false;
        }*/
        modify(LSCPostAndPrintPutAway)
        {
            Promoted = false;
        }
        addafter("Post Receipt")
        {

            action(FSNPostAndPrint)
            {
                ApplicationArea = Warehouse;
                Caption = 'Post and &Print';
                Image = PostPrint;
                Promoted = true;
                PromotedCategory = Category5;
                PromotedIsBig = true;
                ShortCutKey = 'Shift+F9';
                ToolTip = 'Finalize and prepare to print the document or journal. The values and quantities are posted to the related accounts. A report request window where you can specify what to include on the print-out.';

                trigger OnAction()
                var
                //batsendtransfer: Codeunit "FSN Batch - Send Transfer Data";
                begin
                    if BatchPostingActive then
                        Error(BatchPosting.GetBatchPostingActiveTxt());
                    IF CONFIRM('¿Desea aplicar la recepcion? \->Si acepta, el sistema lo aplicará lo mas pronto posible.') THEN BEGIN
                        IF Rec.Status = Rec.Status::AplicandoAutomatico THEN
                            EXIT;
                        Rec.Status := Rec.Status::AplicandoAutomatico;
                        Rec.MODIFY;
                        //batsendtransfer.SendTransferDataAutomatic(Rec);
                        EXIT;
                    END;
                    //CurrPage.WhseReceiptLines.PAGE.WhsePostRcptPrintPostedRcpt;
                end;
            }
        }
    }
    var
        BatchPosting: Codeunit "LSC Batch Posting";
        BatchPostingActive: Boolean;

}