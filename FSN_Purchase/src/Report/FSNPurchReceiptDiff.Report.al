/// <summary>
/// Report Receiving List (ID 50081).
/// </summary>

report 50081 "FSN Receiving List Difference"
{
    DefaultLayout = RDLC;
    RDLCLayout = 'src/Report/Layout/FSNPurchReceiptDiff.rdl';
    Caption = 'Report Receiving Difference';

    dataset
    {

        dataitem(PurchHeader; "Purchase Header")
        {
            PrintOnlyIfDetail = true;
            RequestFilterFields = "No.";
            column(ReportName; 'Reporte Diferencias de Recepción')
            {
            }
            column(FORMAT_TODAY_0_4_; Format(Today, 0, 4))
            {
            }
            column(PurchHeader_Reference_No_; "No.")
            {
            }
            column(PurchHeader_Reference_Name_; PurchHeader."Buy-from Vendor Name")
            {
            }
            dataitem(PurchLine; "Purchase Line")
            {
                DataItemLinkReference = PurchHeader;
                DataItemLink = "Document No." = field("No.");
                DataItemTableView = SORTING("Line No.", "Document No.");
                column(PurchLine__Line_No__; "Line No.")
                {
                }
                column(PurchLine__Item_No__; "No.")
                {
                }
                column(PurchLine_Description; Description)
                {
                }
                column(PurchLine_Quantity; Quantity)
                {
                }
                column(PurchLine_Quantity_Received; QtyReceived)
                {
                }
                column(PurchLine_Difference; Difference)
                {
                }
                column(PurchLine__Variant_code_; "Variant Code")
                {
                }
                column(PurchLine_Reference_No_alternative; ReferenceNoAlternative)
                {
                }
                trigger OnAfterGetRecord()
                begin
                    if PurchLineItemNo.ContainsKey(PurchLine."No.") then begin
                        Difference := PurchLineItemNo.Get(PurchLine."No.");
                        QtyReceived := PurchLine.Quantity - Difference;
                    end else
                        QtyReceived := PurchLine."Quantity Received";
                    if PurchLineItemNoAlt.ContainsKey(PurchLine."No.") then
                        ReferenceNoAlternative := PurchLineItemNoAlt.Get(PurchLine."No.")
                    else
                        ReferenceNoAlternative := '';
                end;

            }
            trigger OnAfterGetRecord()
            begin
                Clear(PurchLineItemNo);
                PurchLn.Reset();
                PurchLn.SetRange("Document Type", PurchHeader."Document Type");
                PurchLn.SetRange("Document No.", PurchHeader."No.");
                if PurchLn.FindSet() then begin
                    repeat
                        if (PurchLn.Quantity - PurchLn."Quantity Received") > 0 then
                            if not PurchLineItemNo.ContainsKey(PurchLn."No.") then
                                PurchLineItemNo.Add(PurchLn."No.", (PurchLn.Quantity - PurchLn."Quantity Received"))
                            else
                                PurchLineItemNo.Set(PurchLn."No.", PurchLineItemNo.Get(PurchLn."No.") + (PurchLn.Quantity - PurchLn."Quantity Received"));
                        PurchHdrAlt.Reset();
                        PurchHdrAlt.SetFilter("Your Reference", '%1', PurchHeader."No.");
                        if PurchHdrAlt.FindFirst() then begin
                            PurchLnAlt.Reset();
                            PurchLnAlt.SetRange("Document No.", PurchHdrAlt."No.");
                            PurchLnAlt.SetFilter("No.", '%1', PurchLn."No.");
                            PurchLnAlt.SetFilter("Quantity", '<>0');
                            if PurchLnAlt.FindFirst() then begin
                                repeat
                                    if not PurchLineItemNoAlt.ContainsKey(PurchLn."No.") then
                                        PurchLineItemNoAlt.Add(PurchLnAlt."No.", PurchHdrAlt."No.");
                                until PurchLnAlt.Next() = 0;
                            end;
                        end;
                    until PurchLn.Next() = 0;
                end;
                if PurchLineItemNo.Count > 0 then begin
                    LSCPRCountingHdr.Reset();
                    LSCPRCountingHdr.SetRange("Reference No.", PurchHeader."No.");
                    LSCPRCountingHdr.SetRange("FSN Authorized Reception", true);
                    if LSCPRCountingHdr.FindFirst() then
                        repeat
                            LSCPickingReceivinglinesVal.Reset();
                            LSCPickingReceivinglinesVal.SetRange("Document No.", LSCPRCountingHdr."No.");
                            LSCPickingReceivinglinesVal.SetFilter("Quantity", '<>0');
                            if LSCPickingReceivinglinesVal.FindFirst() then
                                repeat begin
                                    if PurchLineItemNo.ContainsKey(LSCPickingReceivinglinesVal."Item No.") then
                                        PurchLineItemNo.Set(LSCPickingReceivinglinesVal."Item No.", PurchLineItemNo.Get(LSCPickingReceivinglinesVal."Item No.") - LSCPickingReceivinglinesVal.Quantity);
                                end until LSCPickingReceivinglinesVal.Next() = 0;
                        until LSCPRCountingHdr.Next() = 0;
                end;
            end;

        }
    }

    requestpage
    {

        layout
        {
            area(content)
            {

            }
        }
        actions
        {
        }
    }
    var
        PurchHdrAlt: Record "Purchase Header";
        PurchLn: Record "Purchase Line";
        PurchLnAlt: Record "Purchase Line";
        LSCPRCountingHdr: Record "LSC P/R Counting Header";
        LSCPickingReceivinglinesVal: Record "LSC Picking / Receiving lines";
        PurchLineItemNo: Dictionary of [Code[20], Integer];
        PurchLineLineNo: Dictionary of [Code[20], Integer];
        PurchLineItemNoAlt: Dictionary of [Code[20], Code[20]];
        ItemNo: Code[20];
        ReferenceNoAlternative: Code[20];
        Difference, QtyReceived : Decimal;
}