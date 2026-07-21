report 50003 "FSN Exchange Return Vendor"
{
    DefaultLayout = RDLC;
    RDLCLayout = 'src/Report/Layout/ExchangeReturnVendor.rdlc';

    Caption = 'Exchange Return Vendor';

    dataset
    {
        dataitem("Integer"; "Integer")
        {
            column(Recibo; LocalTemporary."Receipt No.")
            {
            }
            column(Store; LocalTemporary."Store No.")
            {
            }
            column(ItemNo; LocalTemporary."Item No.")
            {
            }
            column(UnitOfMeasure; LocalTemporary."Unit of Measure")
            {
            }
            column(Quantity; LocalTemporary.Quantity)
            {
            }
            column(SalesStaff; LocalTemporary."Sales Staff")
            {
            }
            column(TransDate; LocalTemporary."Transaction Date")
            {
            }
            column(UnitCost; LocalTemporary."Unit Cost")
            {
            }
            column(Laboratory; LocalTemporary."Attrib 1 Code")
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

            trigger OnAfterGetRecord()
            var
                lBarcode: Record "LSC Barcodes";
            begin
                IF Number = 1 THEN
                    LocalTemporary.FIND('-')
                ELSE
                    LocalTemporary.NEXT;

                lBarcode.RESET;
                lBarcode.SETCURRENTKEY("Item No.", "Variant Code", "Unit of Measure Code");
                lBarcode.SETRANGE(lBarcode."Item No.", LocalTemporary."Item No.");
                lBarcode.SETRANGE(lBarcode."Unit of Measure Code", LocalTemporary."Unit of Measure");
                IF lBarcode.FINDFIRST THEN
                    ItemName := lBarcode.Description
                ELSE
                    ItemName := TableExchangeReleased.GetItemDescription(LocalTemporary."Item No.");
            end;

            trigger OnPreDataItem()
            begin
                LocalTemporary.RESET;
                CLEAR(LocalTemporary);

                ReceivedDocumentEntry.GET(KeyUser, KeyEntry);
                ReceivedDocumentEntry.CALCFIELDS(ReceivedDocumentEntry."Net Amount", ReceivedDocumentEntry."VAT Amount");
                DocumentType := DocumentType + '-' + FORMAT(ReceivedDocumentEntry."Group Type");
                TotalDocument := ReceivedDocumentEntry."Net Amount";
                VATPercent := ReceivedDocumentEntry."VAT Amount";

                TableExchangeReleased.RESET;
                TableExchangeReleased.SETCURRENTKEY(Request, "Document Return Key 1", "Document Return Key 2");
                TableExchangeReleased.SETRANGE(TableExchangeReleased."Document Return Key 1", KeyUser);
                TableExchangeReleased.SETRANGE(TableExchangeReleased."Document Return Key 2", KeyEntry);
                IF TableExchangeReleased.FINDSET THEN
                    REPEAT
                        LocalTemporary.INIT();
                        LocalTemporary := TableExchangeReleased;
                        LocalTemporary."Unit Cost" := ROUND(LocalTemporary."Unit Cost", 0.01);
                        LocalTemporary.INSERT();
                        Int += 1;
                    UNTIL TableExchangeReleased.NEXT = 0;

                TableExchangePost.RESET;
                TableExchangePost.SETCURRENTKEY(Request, "Document Return Key 1", "Document Return Key 2");
                TableExchangePost.SETRANGE(TableExchangePost."Document Return Key 1", KeyUser);
                TableExchangePost.SETRANGE(TableExchangePost."Document Return Key 2", KeyEntry);
                IF TableExchangePost.FINDSET THEN
                    REPEAT
                        LocalTemporary.INIT();
                        LocalTemporary.TRANSFERFIELDS(TableExchangePost);
                        LocalTemporary."Unit Cost" := ROUND(LocalTemporary."Unit Cost", 0.01);
                        LocalTemporary.INSERT();
                        Int += 1;
                    UNTIL TableExchangePost.NEXT = 0;

                IF NOT LocalTemporary.FIND('-') THEN
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
        TotalDocument: Decimal;
        VendorName: Text[50];
        StoreName: Text[50];
        DocumentDate: Date;
        KeyUser: Code[50];
        KeyEntry: Integer;
        TableExchangeReleased: Record "FSN POS Exchange Transaction";
        TableExchangePost: Record "POS Posted Exchange Trans.";
        Int: Integer;
        VATPercent: Decimal;
        Reference: Text[75];
        ReceivedDocumentEntry: Record "FSN Document Received Entry";
        LocalTemporary: Record "FSN POS Exchange Transaction" temporary;

    procedure SetValues(pExternalDocNo: Text[50]; pDocumentType: Text[50]; pTotalDocument: Decimal; pVendorName: Text[50]; pStoreName: Text[50]; pDocumentDate: Date; pKeyUser: Code[50]; pKeyEntry: Integer; pReference: Text[75])
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
    end;
}

