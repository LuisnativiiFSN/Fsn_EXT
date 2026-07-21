pageextension 50062 "FSN RetailTransferOrderList" extends "LSC Retail Transfer Order List" //"Retail Transfer Order List"
{
    layout
    {
        addafter(Status)
        {
            field("FSN Consolidate No."; "FSN Consolidate No.")
            {
            }
        }
    }

    actions
    {
        addafter("Re&lease")
        {
            action("Send External Lines")
            {
                Image = CopyWorksheet;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    LSMenu: Text[100];
                    Location_l: Record Location;
                    SendDataFrontier: Codeunit "FSN Batch - Send Transfer Data";
                    IDSelected: Option " ","Only Selected","All Transfer";
                    ExternalTransferData_l: Record PITS_WMScd2suc;
                    lText001: Label 'Send data sussesfull!';
                    lText002: Label 'Transfer No. %1 alredy exists';
                    lTextMenu: Label '&Transfer Selected %1, &All Transfers';
                    lText003: Label 'Location %1 is not configured for Transfer external data';
                begin
                    LSMenu := STRSUBSTNO(lTextMenu, "No.");
                    IDSelected := STRMENU(LSMenu, 1);

                    CASE IDSelected OF
                        0:
                            EXIT;

                        1:
                            BEGIN
                                TESTFIELD(Status, Status::Released);
                                Location_l.GET("Transfer-from Code");
                                IF NOT (Location_l."LSC Location is a Warehouse" AND Location_l."Require Receive" AND Location_l."Require Shipment") THEN
                                    ERROR(STRSUBSTNO(lText003, Location_l.Name));
                                ExternalTransferData_l.RESET;
                                ExternalTransferData_l.SETCURRENTKEY("Source No.", "Item No.");
                                ExternalTransferData_l.SETRANGE(ExternalTransferData_l."Source No.", "No.");
                                IF ExternalTransferData_l.FINDFIRST THEN BEGIN
                                    MESSAGE(STRSUBSTNO(lText002, "No."));
                                    EXIT;
                                END ELSE
                                    SendDataFrontier.SendLines(Rec);
                            END;

                        2:
                            BEGIN
                                SendDataFrontier.RUN;
                            END;
                    END;

                    MESSAGE(lText001);
                end;
            }
        }
        addlast(Navigation)
        {
            action("PITS Data Sent")
            {
                Image = TransferOrder;
                Promoted = true;
                PromotedCategory = Process;
                RunObject = page "FSN PITSWMScd2suc";
                RunPageLink = "No." = field("No.");
            }
        }
    }
}