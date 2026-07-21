pageextension 50071 "FSN RetailPurchOrderExt" extends "LSC Retail Purch. Order Store"
{
    layout
    {
        addafter(Status)
        {
            field("FSN Consolidate No."; "FSN Consolidate No.")
            {
                ApplicationArea = all;
            }
        }
    }
    actions
    {
        addafter(Release)
        {
            action(SetConsolidate)
            {
                Caption = 'Set Consolidate';
                Image = CopyBOMVersion;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    ConsolidateNo: Code[20];
                    VendorInFunction: Code[20];
                    SetCount: Integer;
                    PurchaseHeader_l: Record "Purchase Header";
                    PurchaseHeader2_l: Record "Purchase Header";
                    NoSeriesMgt: Codeunit NoSeriesManagement;
                    ReplenSetup_l: Record "LSC Replen. Setup";
                    lText001: Label 'Do you want to add consolidated number to %1 records?';
                    lText002: Label 'Consolidate %1 assigment to %2 records';
                    lText003: Label 'Vendor %1 must be equal of all orders selected';
                    lText004: Label 'there are no marked records or have a consolidated number';
                    lText005: Label 'Status must be Released %1';
                    lText006: Label 'Consolidate %1 alredy exists in other purchase order group. Try activity';
                begin
                    ConsolidateNo := '';
                    SetCount := 0;
                    VendorInFunction := "Buy-from Vendor No.";
                    ReplenSetup_l.Get();
                    ReplenSetup_l.TestField("FSN Consolidate Serie No.");

                    CurrPage.SETSELECTIONFILTER(PurchaseHeader_l);

                    IF PurchaseHeader_l.FINDSET THEN
                        REPEAT
                            IF PurchaseHeader_l."Buy-from Vendor No." <> VendorInFunction THEN
                                ERROR(STRSUBSTNO(lText003, VendorInFunction));
                            IF PurchaseHeader_l.Status <> PurchaseHeader_l.Status::Released THEN
                                ERROR(STRSUBSTNO(lText005, PurchaseHeader_l."No."));
                            IF PurchaseHeader_l."FSN Consolidate No." = '' THEN
                                SetCount += 1;
                        UNTIL PurchaseHeader_l.NEXT = 0;

                    IF SetCount < 1 THEN
                        ERROR(lText004);


                    IF NOT CONFIRM(STRSUBSTNO(lText001, FORMAT(SetCount))) THEN
                        EXIT;

                    ConsolidateNo := NoSeriesMgt.GetNextNo(ReplenSetup_l."FSN Consolidate Serie No.", TODAY, TRUE);
                    IF ConsolidateNo = '' THEN
                        EXIT;

                    PurchaseHeader2_l.RESET;
                    PurchaseHeader2_l.SETRANGE(PurchaseHeader2_l."FSN Consolidate No.", ConsolidateNo);
                    IF PurchaseHeader2_l.FINDFIRST THEN BEGIN
                        MESSAGE(lText006, ConsolidateNo);
                        EXIT;
                    END;

                    IF PurchaseHeader_l.FINDSET THEN
                        REPEAT
                            IF PurchaseHeader_l."FSN Consolidate No." = '' THEN
                                IF PurchaseHeader2_l.GET(PurchaseHeader_l."Document Type", PurchaseHeader_l."No.") THEN BEGIN
                                    PurchaseHeader2_l."FSN Consolidate No." := ConsolidateNo;
                                    PurchaseHeader2_l.MODIFY;
                                END;
                        UNTIL PurchaseHeader_l.NEXT = 0;

                    MESSAGE(STRSUBSTNO(lText002, ConsolidateNo, FORMAT(SetCount)));
                end;
            }
        }
    }
}