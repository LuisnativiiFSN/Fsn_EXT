report 50001 "FSN Remission"
{
    DefaultLayout = RDLC;
    RDLCLayout = './src/Report/Layout/Remission.rdl';
    PreviewMode = PrintLayout;

    dataset
    {
        dataitem(NotaRemisionHeader; "FSN Remission Header")
        {
            column(Numero; NotaRemisionHeader."No.")
            {
                IncludeCaption = true;
            }
            column(Cliente; NotaRemisionHeader."Customer No.")
            {
                IncludeCaption = true;
            }
            column(Fecha; NotaRemisionHeader."Document Date")
            {
                IncludeCaption = true;
            }
            column(CodigoAsegurado; NotaRemisionHeader."Insured Parent Card No.")
            {
                IncludeCaption = true;
            }
            column(Asegurado; NotaRemisionHeader."Insured Name")
            {
                IncludeCaption = true;
            }
            column(Parentesco; NotaRemisionHeader.Relation)
            {
                IncludeCaption = true;
            }
            column(Titular; NotaRemisionHeader."Insured Parent Name")
            {
                IncludeCaption = true;
            }
            column(TipoCoaseguro; NotaRemisionHeader."Coinsurance No.")
            {
                IncludeCaption = true;
            }
            column(Porcentaje; NotaRemisionHeader."Coinsurance Percent")
            {
                IncludeCaption = true;
            }
            column(Coaseguro; NotaRemisionHeader."Coinsurance Value")
            {
                IncludeCaption = true;
            }
            column(Total; NotaRemisionHeader.Amount)
            {
                IncludeCaption = true;
            }
            column(TotalIva; NotaRemisionHeader."Amount Including VAT")
            {
                IncludeCaption = true;
            }
            column(XPagar; NotaRemisionHeader."Amount Including VAT")
            {
                IncludeCaption = true;
            }
            column(Vendedor; NotaRemisionHeader."Sales Staff")
            {
                IncludeCaption = true;
            }
            column(ValorTexto; ValorTexto)
            {
            }
            column(StaffNameText; StaffNameText)
            {
            }
            column(StoreNameText; StoreNameText)
            {
            }
            column(PrintType; PrintType)
            {
            }
            column(DiscountAmt; DiscountAmt)
            {
            }
            dataitem(Customer; Customer)
            {
                DataItemLink = "No." = FIELD("Customer No.");
                DataItemLinkReference = NotaRemisionHeader;
                column(Giro; Customer."FSN NRC Description") //Giro 
                {
                    IncludeCaption = true;
                }
                column(NombreCliente; Customer.Name)
                {
                }
                column(Direccion; Customer.Address)
                {
                }
                column(NIT; Customer."VAT Registration No.")
                {
                    IncludeCaption = true;
                }
                column(NRC; Customer."RFC No.") //NRC
                {
                    IncludeCaption = true;
                }
            }
            dataitem(Store; "LSC Store")
            {
                DataItemLink = "No." = FIELD("Store No.");
                DataItemLinkReference = NotaRemisionHeader;
                column(StoreName; Store.Name)
                {
                    IncludeCaption = true;
                }
            }
            dataitem(Insured; "FSN Insured Links")
            {
                DataItemLink = "Company No." = FIELD("Company No."),
                               Card = FIELD("Insured Card No.");
                DataItemLinkReference = NotaRemisionHeader;
                column(CodEmpresa; Insured."Company No.")
                {
                    IncludeCaption = true;
                }
            }
            dataitem(NotaRemisionLine; "FSN Remission Line")
            {
                DataItemLink = "Document Type" = FIELD("Document Type"),
                               "Document No." = FIELD("No.");
                DataItemLinkReference = NotaRemisionHeader;
                DataItemTableView = SORTING("Document Type", "Document No.", "Line No.")
                                    WHERE(Type = CONST(Item));
                column(Codigo; NotaRemisionLine."No.")
                {
                    IncludeCaption = true;
                }
                column(Descripcion; NotaRemisionLine.Description)
                {
                    IncludeCaption = true;
                }
                column(Unidad; NotaRemisionLine."Unit of Measure")
                {
                    IncludeCaption = true;
                }
                column(Cantidad; NotaRemisionLine.Quantity)
                {
                    IncludeCaption = true;
                }
                column(Unitario; NotaRemisionLine."Unit Price")
                {
                    IncludeCaption = true;
                }
                column(UnitarioIVA; NotaRemisionLine."Unit Price Inc. VAT")
                {
                    IncludeCaption = true;
                }
                column(Valor; NotaRemisionLine.Amount)
                {
                    IncludeCaption = true;
                }
                column(Descuento; NotaRemisionLine."Discount %")
                {
                    IncludeCaption = true;
                }
                column(PorcIVA; NotaRemisionLine."VAT Amount")
                {
                    IncludeCaption = true;
                }
                column(ValorMasIVA; NotaRemisionLine."Amount Including VAT")
                {
                    IncludeCaption = true;
                }
                column(NumReceta; NotaRemisionLine.Recipe)
                {
                    IncludeCaption = true;
                }
                column(PriceRecalc; PriceRecalc)
                {
                }
                column(DiscountLine; DiscountLine)
                {
                }

                trigger OnAfterGetRecord()
                begin
                    IF NotaRemisionLine."Discount Amount" = 0 THEN
                        DiscountLine := 0
                    ELSE
                        DiscountLine := ROUND((NotaRemisionLine."Unit Price" * NotaRemisionLine.Quantity) - (NotaRemisionLine.Amount), 0.01, '=');

                end;

                trigger OnPreDataItem()
                begin
                    DiscountAmt := 0;
                end;
            }

            trigger OnAfterGetRecord()
            var
                FSNUtility: Codeunit "FSN Utility";
                Store: Record "LSC Store";
                Staff: Record "LSC Staff";
                TextStaff: Label 'Staff: %1 - %2 %3';
                CompanyIns: Record "FSN Company Insurer";
                RemissionLine_l: Record "FSN Remission Line";
                NewPrice: Decimal;
            begin
                ValorTexto := FSNUtility.Num2Text(ROUND("Amount Including VAT", 0.01, '='));
                IF Store.GET(NotaRemisionHeader."Store No.") THEN
                    StoreNameText := Store.Name;
                IF Staff.GET(NotaRemisionHeader."Sales Staff") THEN
                    StaffNameText := STRSUBSTNO(TextStaff, Staff.ID, Staff."First Name", Staff."Last Name");

                PrintType := 0;
                IF CompanyIns.GET(NotaRemisionHeader."Company No.") THEN
                    PrintType := CompanyIns."Print Insured Links";

                DiscountAmt := 0;
                RemissionLine_l.RESET;
                RemissionLine_l.SETRANGE(RemissionLine_l."Document Type", NotaRemisionHeader."Document Type");
                RemissionLine_l.SETRANGE(RemissionLine_l."Document No.", NotaRemisionHeader."No.");
                IF RemissionLine_l.FIND('-') THEN
                    REPEAT

                        IF RemissionLine_l."Discount Amount" <> 0 THEN
                            DiscountAmt += ROUND((RemissionLine_l."Unit Price" * RemissionLine_l.Quantity) - (RemissionLine_l.Amount), 0.01, '=');
                    UNTIL RemissionLine_l.NEXT = 0;

                DiscountAmt := -DiscountAmt;
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
        ValorTexto: Text[100];
        StaffNameText: Text[150];
        StoreNameText: Text[50];
        PrintType: Integer;
        PriceRecalc: Decimal;
        DiscountAmt: Decimal;
        DiscountLine: Decimal;
}

