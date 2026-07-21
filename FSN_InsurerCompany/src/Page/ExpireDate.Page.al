page 50089 "FSN ExpireDate"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    DeleteAllowed = false;
    SourceTable = "LSC POS Trans. Line";
    SourceTableTemporary = true;
    Caption = 'Fecha Expiración';

    layout
    {
        area(Content)
        {
            group(GroupName)
            {

                field(month; Fecha)
                {
                    Caption = 'Fecha Expiración';
                    ApplicationArea = All;
                    Editable = true;

                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        GetYearFromDate(Fecha, Rec);
                    end;

                }
            }
        }
    }

    var
        myInt: Integer;
        Fecha: Date;
        ERRORDATE: Label 'Fecha no puede ser vacia';
        GlobalPosTransLineTemp: Record "LSC POS Trans. Line";
        posession: Codeunit "LSC POS Session";
        postransactionC: Codeunit "LSC POS Transaction";

    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        Fecha := 0D;
    end;

    trigger OnClosePage()
    var
        myInt: Integer;
        ExpireDatePage: Page "FSN ExpireDate";
    begin
        if Fecha = 0D then begin
            Message(ERRORDATE);
            ExpireDatePage.SetRecord(Rec);
            ExpireDatePage.run();
        end else
            posession.SetValue('#NOLOTE', '');
    end;

    procedure GetYearFromDate(DateValue: Date; posTransLinetemp: Record "LSC POS Trans. Line" temporary): Integer
    var
        posTransLine: Record "LSC POS Trans. Line";
        ValLineNo: Integer;
    begin
        if Evaluate(ValLineNo, posession.GetValue('#LOTELINE')) then;
        posTransLine.Reset();
        //posTransLine.SetRange(posTransLine."Store No.", posession.StoreNo());
        //posTransLine.SetRange(posTransLine."POS Terminal No.", posession.TerminalNo());
        posTransLine.SetRange(posTransLine."Receipt No.", postransactionC.GetReceiptNo());
        posTransLine.SetRange(posTransLine."Entry Type", posTransLine."Entry Type"::Item);
        posTransLine.SetRange(posTransLine.Number, posession.GetValue('#NOLOTE'));
        posTransLine.SetRange(posTransLine."Line No.", ValLineNo);
        posTransLine.SETFILTER(posTransLine."Entry Status", '<>%1', posTransLine."Entry Status"::Voided);
        if posTransLine.FindFirst() then begin
            posTransLine."Expiration Date" := DateValue;
            posTransLine.Modify(true);
        end;
        // exit(Year(DateValue));
    end;


    procedure SETGLOBALVALUE(POSTransLineTemp: Record "LSC POS Trans. Line")
    begin
        GlobalPosTransLineTemp := POSTransLineTemp;
    end;
}