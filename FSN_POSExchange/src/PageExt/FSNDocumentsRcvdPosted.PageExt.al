pageextension 50066 "FSN Documents Rcvd. Posted Ext" extends "FSN Documents Rcvd. Posted"
{

    actions
    {
        addafter(DocumentLines)
        {
            action("Print")
            {
                Image = Print;
                Promoted = true;
                PromotedCategory = "Report";
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    PrintDocument(Rec);
                end;
            }
        }
    }

    procedure PrintDocument(RecPrint: Record "FSN Document Received Entry")
    var
        ReportExchangeReturn: Report "FSN Exchange Return Vendor";
        ReportExchangeReceipt: Report "FSN Exchange Receipt";
        lStore: Record "LSC Store";
        lCompany: Record "Company Information";
        StoreName: Text[75];
        Text000: Label 'It is printed when products linked exists';
    begin

        CASE RecPrint."Entry Type" OF
            RecPrint."Entry Type"::Purchase:
                BEGIN
                    CASE TRUE OF
                        (RecPrint."Document Type" = RecPrint."Document Type"::"Delivery To Vendor") AND (RecPrint."Group Type" = RecPrint."Group Type"::Exchange):
                            BEGIN

                                CLEAR(ReportExchangeReturn);
                                RecPrint.CALCFIELDS("Net Amount");
                                IF lStore.GET(RecPrint."Store LS Retail") THEN;
                                ReportExchangeReturn.SetValues(RecPrint."External Document No.", RecPrint."Document Type Text", RecPrint."Net Amount", RecPrint.Description, lStore.Name,
                                  RecPrint."Posting Date", RecPrint."User ID", RecPrint."Entry Posted No.", RecPrint."Reference Key");
                                ReportExchangeReturn.RUN;
                            END;
                        ((RecPrint."Document Type" = RecPrint."Document Type"::Receipt) AND (RecPrint."Group Type" = RecPrint."Group Type"::Exchange)),
                        ((RecPrint."Document Type" = RecPrint."Document Type"::"Credit Note") AND (RecPrint."Group Type" = RecPrint."Group Type"::Exchange)):
                            BEGIN

                                StoreName := '';
                                CLEAR(ReportExchangeReceipt);
                                RecPrint.CALCFIELDS("Net Amount");

                                IF lCompany.GET THEN;
                                IF lStore.GET(RecPrint."Store LS Retail") THEN
                                    StoreName := lStore."No." + '-' + lStore.Name
                                ELSE
                                    StoreName := lCompany.Name;

                                ReportExchangeReceipt.SetValues(RecPrint."External Document No.", RecPrint.Comment, RecPrint."Net Amount", RecPrint.Description, StoreName,
                                  RecPrint."Posting Date", RecPrint."User ID", RecPrint."Entry Posted No.", RecPrint."Reference Key", RecPrint."Document Type Text");
                                ReportExchangeReceipt.RUN;
                            END;
                        ELSE
                            MESSAGE(Text000);
                    END;
                END;
            ELSE
                MESSAGE(Text000);
        END;
    end;

}