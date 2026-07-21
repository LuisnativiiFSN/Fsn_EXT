page 50070 "FSN Transfer Scanner"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Global Table Temporary";
    SourceTableTemporary = true;
    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                field(Scanner; Code20_3)
                {
                    Caption = 'Scanner';
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        TransferLine_l: Record "Transfer Line";
                        Item: Record Item;
                        Barcodes: Record "LSC Barcodes";
                        FSNSetup: Record "FSN Fasani Setup";
                    begin
                        FSNSetup.Get(TransferHeader."LSC Store-from");
                        if not Barcodes.Get(Code20_3) then begin
                            Rec.Code20_3 := '';
                            Message(Txt1);
                            exit;
                        end;

                        if not Item.Get(Barcodes."Item No.") then begin
                            Rec.Code20_3 := '';
                            Message(Txt1);
                            exit;
                        end;

                        TransferLine_l.Reset();
                        TransferLine_l.SetRange("Document No.", Code20_1);
                        TransferLine_l.SetRange("Item No.", Item."No.");
                        if TransferLine_l.find('-') then
                            repeat
                                if not TransferLine_l."FSN Checked" then begin
                                    if (TransferLine_l."Qty. to Ship" + 1) <= TransferLine_l.Quantity then begin
                                        if FSNSetup."Receive Directly" then
                                            TransferLine_l.Validate("Qty. to Ship", TransferLine_l.Quantity)
                                        else
                                            TransferLine_l.Validate("Qty. to Ship", TransferLine_l."Qty. to Ship" + 1);
                                        if TransferLine_l."Qty. to Ship" = TransferLine_l.Quantity then
                                            TransferLine_l."FSN Checked" := true;
                                        TransferLine_l.Modify(true);
                                        if (TransferLine_l."Qty. to Ship") = TransferLine_l.Quantity then
                                            Message(Txt0);
                                    end else
                                        Message(Txt0);
                                end else
                                    Message(Txt0);
                            until TransferLine_l.Next() = 0
                        else
                            Message(Txt1);
                        Rec.Code20_3 := '';

                    end;
                }
            }
            group(Detail)
            {
                part(TransferLines; "LSC Retail TO. Subp.")
                {
                    Editable = false;
                    ApplicationArea = All;
                    SubPageLink = "Document No." = FIELD(FILTER(Code20_1));
                }

            }
        }
    }

    trigger OnOpenPage()
    var
        transfer_l: Record "Transfer Line";
    begin
        Rec.Reset();
        Rec.DeleteAll(true);
        Rec.Init();
        Rec.Code20_1 := GlobalTransferNo;
        Rec.Code20_3 := '';
        Rec.Insert();

        TransferHeader.Get(GlobalTransferNo);
        transfer_l.Reset();
        transfer_l.SetRange("Document No.", GlobalTransferNo);
        transfer_l.SetRange("Derived From Line No.", 0);
        if TransferHeader.Status = TransferHeader.Status::Open then
            if transfer_l.Find('-') then
                repeat
                    if not transfer_l."FSN Checked" then begin
                        transfer_l.Validate(transfer_l."Qty. to Ship", 0);
                        transfer_l.Modify(true);
                    end;
                until transfer_l.Next() = 0;
    end;

    procedure SetPurchOrderNo(pReceipt: Code[20])
    begin
        GlobalTransferNo := pReceipt;
    end;

    var
        TransferHeader: Record "Transfer Header";
        GlobalTransferNo: Code[20];
        Txt0: Label 'Line completed.';
        Txt1: Label 'Barcode not found';
}