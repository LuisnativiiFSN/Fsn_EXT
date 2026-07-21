report 50002 "FSN Exchange Receipt"
{
    // WVILLALTA04DIC19              - New report
    DefaultLayout = RDLC;
    RDLCLayout = 'src/Report/Layout/ExchangeReceipt.rdlc';

    Caption = 'Exchange Return Vendor';

    dataset
    {
        dataitem("Integer"; "Integer")
        {
            column(Recibo; GlobalTemporary."Receipt No.")
            {
            }
            column(Store; GlobalTemporary."Store No.")
            {
            }
            column(ItemNo; GlobalTemporary."Item No.")
            {
            }
            column(UnitOfMeasure; GlobalTemporary."Unit of Measure")
            {
            }
            column(Quantity; GlobalTemporary.Quantity)
            {
            }
            column(SalesStaff; GlobalTemporary."Sales Staff")
            {
            }
            column(TransDate; GlobalTemporary."Transaction Date")
            {
            }
            column(UnitCost; GlobalTemporary."Unit Cost")
            {
            }
            column(Laboratory; GlobalTemporary."Attrib 1 Code")
            {
            }
            column(VATPercent; VATPercent)
            {
            }
            column(SalesDocumentNo; SalesDocumentNo)
            {
            }
            column(ItemName; ItemName)
            {
            }
            column(ExternalDocNo; ExternalDocNo)
            {
            }
            column(DocumentType; DocumentType)
            {
            }
            column(TotalDocument; TotalDocument)
            {
            }
            column(VendorName; VendorName)
            {
            }
            column(StoreName; StoreName)
            {
            }
            column(DocumentDate; DocumentDate)
            {
            }
            column(UserNo; KeyUser)
            {
            }
            column(EntryNo; KeyEntry)
            {
            }
            column(ReferenceKey; Reference)
            {
            }
            column(DocumentRefName; DocumentRefName)
            {
            }

            trigger OnAfterGetRecord()
            var
                lBarcode: Record "LSC Barcodes";
            begin
                IF Number = 1 THEN
                    GlobalTemporary.FIND('-')
                ELSE
                    GlobalTemporary.NEXT;

                lBarcode.RESET;
                lBarcode.SETCURRENTKEY("Item No.", "Variant Code", "Unit of Measure Code");
                lBarcode.SETRANGE(lBarcode."Item No.", GlobalTemporary."Item No.");
                lBarcode.SETRANGE(lBarcode."Unit of Measure Code", GlobalTemporary."Unit of Measure");
                IF lBarcode.FINDFIRST THEN
                    ItemName := lBarcode.Description
                ELSE
                    ItemName := GlobalTemporary.GetItemDescription(GlobalTemporary."Item No.");
            end;

            trigger OnPreDataItem()
            begin
                GlobalTemporary.RESET;
                CLEAR(GlobalTemporary);

                ReceivedDocumentEntry.GET(KeyUser, KeyEntry);
                ReceivedDocumentEntry.CALCFIELDS(ReceivedDocumentEntry."Net Amount", ReceivedDocumentEntry."VAT Amount");
                DocumentType := DocumentType;
                TotalDocument := ReceivedDocumentEntry."Net Amount";
                VATPercent := ReceivedDocumentEntry."VAT Amount";

                TableExchangeReleased.RESET;
                TableExchangeReleased.SETCURRENTKEY("Document Receipt Key 1", "Document Receipt Key 2", "Autorization Type");
                TableExchangeReleased.SETRANGE(TableExchangeReleased."Document Receipt Key 1", KeyUser);
                TableExchangeReleased.SETRANGE(TableExchangeReleased."Document Receipt Key 2", KeyEntry);
                IF TableExchangeReleased.FINDSET THEN
                    REPEAT
                        GlobalTemporary.INIT();
                        GlobalTemporary := TableExchangeReleased;
                        GlobalTemporary."Unit Cost" := ROUND(GlobalTemporary."Unit Cost", 0.01);
                        GlobalTemporary.INSERT();
                        Int += 1;
                    UNTIL TableExchangeReleased.NEXT = 0;
                TableExchangePost.RESET;
                TableExchangePost.SETCURRENTKEY("Document Receipt Key 1", "Document Receipt Key 2", "Autorization Type");
                TableExchangePost.SETRANGE(TableExchangePost."Document Receipt Key 1", KeyUser);
                TableExchangePost.SETRANGE(TableExchangePost."Document Receipt Key 2", KeyEntry);
                IF TableExchangePost.FINDSET THEN
                    REPEAT
                        GlobalTemporary.INIT();
                        GlobalTemporary.TRANSFERFIELDS(TableExchangePost);
                        GlobalTemporary."Unit Cost" := ROUND(GlobalTemporary."Unit Cost", 0.01);
                        GlobalTemporary.INSERT();
                        Int += 1;
                    UNTIL TableExchangePost.NEXT = 0;

                IF NOT GlobalTemporary.FIND('-') THEN
                    CurrReport.BREAK;
                Integer.SETRANGE(Integer.Number, 1, Int);
            end;
        }
    }

    requestpage
    {

        layout
        {
        }

        actions
        {
        }
    }

    labels
    {
    }

    var
        SalesDocumentNo: Text[50];
        ItemName: Text[50];
        ExternalDocNo: Text[50];
        DocumentType: Text[50];
        DocumentRefName: Text[50];
        TotalDocument: Decimal;
        VendorName: Text[50];
        StoreName: Text[75];
        DocumentDate: Date;
        GlobalTemporary: Record "FSN POS Exchange Transaction" temporary;
        KeyUser: Code[50];
        KeyEntry: Integer;
        TableExchangeReleased: Record "FSN POS Exchange Transaction";
        TableExchangePost: Record "POS Posted Exchange Trans.";
        Int: Integer;
        VATPercent: Decimal;
        Reference: Text[75];
        ReceivedDocumentEntry: Record "FSN Document Received Entry";

    procedure SetValues(pExternalDocNo: Text[50]; pDocumentType: Text[50]; pTotalDocument: Decimal; pVendorName: Text[50]; pStoreName: Text[75]; pDocumentDate: Date; pKeyUser: Code[50]; pKeyEntry: Integer; pReference: Text[75]; pDocumentRefName: Text[50])
    begin
        ExternalDocNo := pExternalDocNo;
        DocumentType := pDocumentType;
        TotalDocument := pTotalDocument;
        VendorName := pVendorName;
        StoreName := pStoreName;
        DocumentDate := pDocumentDate;
        KeyUser := pKeyUser;
        KeyEntry := pKeyEntry;
        Reference := pReference;
        DocumentRefName := pDocumentRefName;
    end;
}

