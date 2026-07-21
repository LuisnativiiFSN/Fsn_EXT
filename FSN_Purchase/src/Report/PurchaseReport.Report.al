report 50046 "Purchase Report"
{
    // FSNFRODRIGUEZ07DIC2018          - The branch code was added to the header.
    // FSNFRODRIGUEZ21MAR2019          - The body of the report was adjusted so as not to duplicate the header when printing.
    ApplicationArea = All;
    UsageCategory = Administration;
    PreviewMode = PrintLayout;
    DefaultLayout = RDLC;
    RDLCLayout = 'src/Report/Layout/PurchaseReport.rdl';
    Caption = 'FSN Purchase Report';


    dataset
    {
        dataitem(PurchInvHeader; "Purch. Rcpt. Header")
        {
            //The property 'DataItemTableView' shouldn't have an empty value.
            //DataItemTableView = '';
            RequestFilterFields = "Location Code";
            column(No_PurchInvHeader; PurchInvHeader."No.")
            {
            }
            column(PostingDate_PurchInvHeader; PurchInvHeader."Posting Date")
            {
            }
            column(DocumentDate_PurchInvHeader; PurchInvHeader."Document Date")
            {
            }
            column(LocationCode_PurchInvHeader; PurchInvHeader."Location Code")
            {
            }
            column(Amount_PurchInvHeader; PurchInvHeader.SubTotal)
            {
            }
            column(AmountIncludingVAT_PurchInvHeader; PurchInvHeader.Total)
            {
            }
            column(PaytoName_PurchInvHeader; PurchInvHeader."Pay-to Name")
            {
            }
            column(Starting_Date; StartingDate)
            {
            }
            column(Ending_Date; EndingDate)
            {
            }
            column(Store_name; StoreName)
            {
            }
            column(Company_name; CompanyFormerName)
            {
            }
            column(VendorInvoiceNo_PurchInvHeader; PurchInvHeader."FSN Vendor Invoice No.")
            {
            }
            column(UserID; Usr)
            {
            }
            column(TotaLineAmount_PurchLine; TotaLinea)
            {
            }
            column(Almacen; PurchInvHeader."Location Code")
            {
            }

            trigger OnAfterGetRecord()
            begin

                PurInvLine.RESET;
                TotaLinea := 0;
                PurInvLine.SETRANGE("Document No.", PurchInvHeader."No.");
                IF PurInvLine.FINDFIRST THEN BEGIN
                    PurInvLine.CALCSUMS("Job Line Amount");
                    IF (PurInvLine."VAT %" = '0') THEN
                        TotaLinea := PurInvLine."Job Line Amount"
                    ELSE
                        TotaLinea := PurInvLine."Job Line Amount" * 1.13;


                END;
            end;


            trigger OnPreDataItem()
            var
                RetailUS: Record "LSC Retail User";
                TEXT000: Label 'El usuario actual no esta asociado a esta tienda';
            begin
                Location := PurchInvHeader.GETFILTER("Location Code");
                SETRANGE(PurchInvHeader."Posting Date", StartingDate, EndingDate);

                RetailUser.RESET;
                RetailUser.SETRANGE(ID, USERID);
                IF RetailUser.FINDFIRST THEN BEGIN
                    Usr := RetailUser.ID;
                    IF (RetailUser."Location Code" = Location) OR (RetailUser."Location Code" = '') THEN
                        SETRANGE("Location Code", Location)
                    ELSE
                        ERROR(TEXT000);
                END;

                Store.RESET;
                Store.SETRANGE(Store."Location Code", Location);
                IF Store.FINDFIRST THEN
                    StoreName := Store.Name;
                CalculateTotals();

            end;
        }
    }

    requestpage
    {

        layout
        {
            area(content)
            {
                group("Rango de Fechas")
                {
                    Caption = 'Rango de Fechas';
                    field(StartingDate; StartingDate)
                    {
                        Caption = 'Start Date';
                    }
                    field(EndingDate; EndingDate)
                    {
                        Caption = 'End Date';
                    }
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }

    trigger OnPreReport()
    begin
        CompanyInfo.RESET;
        CompanyInfo.SETRANGE("Name 2", COMPANYNAME);
        IF CompanyInfo.FINDFIRST THEN BEGIN
            CompanyFormerName := CompanyInfo.Name;
        END;
    end;

    var
        StartingDate: Date;
        EndingDate: Date;
        CompanyFormerName: Text[50];
        StoreName: Text[30];
        Usr: Code[50];
        Location: Code[20];
        Disc: Decimal;
        LineAmt: Decimal;
        TotaLinea: Decimal;
        CompanyInfo: Record "Company Information";
        RetailUser: Record "LSC Retail User";
        PurInvLine: Record "Purch. Rcpt. Line";
        VatEntry: Record "VAT Entry";
        Store: Record "LSC Store";

    procedure CalculateTotals()
    var
        PurchRcptHdr2: Record "Purch. Rcpt. Header";
        PurchRcptLn: Record "Purch. Rcpt. Line";
        subTotalBase, vatBase, TotalBase : Decimal;
        IUM: Record "Item Unit of Measure";
        Currency: Record Currency;
        DirectUnitCost: Decimal;
    begin

        PurchRcptHdr2.Reset();
        PurchRcptHdr2.SETRANGE(PurchRcptHdr2."Location Code", Location);
        PurchRcptHdr2.SETRANGE(PurchRcptHdr2."Posting Date", StartingDate, EndingDate);
        if PurchRcptHdr2.FindFirst() then
            repeat
                //Reiniciar Varibales 
                DirectUnitCost := 0;
                subTotalBase := 0;
                vatBase := 0;
                TotalBase := 0;

                if PurchRcptHdr2.Total = 0 then begin
                    PurchRcptLn.Reset();
                    PurchRcptLn.SetRange("Document No.", PurchRcptHdr2."No.");
                    PurchRcptLn.SetFilter(Quantity, '>%1', 0);
                    if PurchRcptLn.FindSet() then
                        repeat
                            DirectUnitCost := PurchRcptLn."Direct Unit Cost";
                            subTotalBase += Round(DirectUnitCost * (PurchRcptLn.Quantity), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                            vatBase += (DirectUnitCost * (PurchRcptLn.Quantity)) * (PurchRcptLn."VAT %" / 100);
                        until PurchRcptLn.Next = 0;
                    PurchRcptHdr2."Subtotal" := subTotalBase;
                    PurchRcptHdr2."Tax" := vatBase;
                    PurchRcptHdr2."Total" := subTotalBase + vatBase;
                    PurchRcptHdr2.Modify(true);
                end;
            until PurchRcptHdr2.NEXT = 0;
    end;

}