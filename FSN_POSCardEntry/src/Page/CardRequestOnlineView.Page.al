page 50085 "FSN Card Request Online View"
{
    PageType = Card;
    SourceTable = "LSC POS Card Entry";

    layout
    {
        area(content)
        {
            group(General)
            {
                ShowCaption = false;
                field("Receipt No."; "Receipt No.")
                {
                    Editable = false;
                }
                field(Card; CardGlobal)
                {
                    Caption = 'Card';
                    Editable = false;
                }
                field(ExpiryDate; ValidDateGlobal)
                {
                    Caption = 'Expiry Date';
                    Editable = false;

                    trigger OnValidate()
                    begin
                        IF "Authorisation Ok" THEN
                            EXIT;
                        "Expiry Date" := ConvertLastDateToParameter(ValidDateGlobal);
                    end;
                }
                field("Auth.code"; "Auth.code")
                {
                    Editable = EditFormat;
                }
                field("EFT Terminal ID"; "EFT Terminal ID")
                {
                    Caption = 'EFT Terminal ID';
                    Editable = EditFormat;
                    Visible = false;
                }
                field("FSN CVV"; "FSN CVV")
                {
                    Editable = false;
                }
                field("FSN Bank Name"; "FSN Bank Name")
                {
                    Editable = EditFormat;
                }
                field(Amount; Amount)
                {
                    Editable = false;
                }
                field("FSN Print Amount"; "FSN Print Amount")
                {
                    Caption = 'Print Amount';
                    Editable = EditFormat;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CLEAR(CardGlobal);
        CLEAR(ValidDateGlobal);
        CardGlobal := GetCardNo;
        ValidDateGlobal := ConvertLastDateFromParameter("Expiry Date");
    end;

    trigger OnOpenPage()
    begin
        EditFormat := NOT "Authorisation Ok";

    end;

    var
        CardGlobal: Text[50];
        EditFormat: Boolean;
        Text011: Label '%1 : must be format: MM/YY';
        Text012: Label '%1 : Month cant be higher to 12 and less to Zero. (MM/YY)';
        Text013: Label '%1 : Year must be higher to 2000 and less to 2100. (MM/YY)';
        ValidDateGlobal: Text[5];

    procedure ConvertLastDateToParameter(pLastCardDate: Text[5]): Text[5]
    var
        _Int: Integer;
    begin

        IF (STRPOS(pLastCardDate, '/') = 0) OR (STRLEN(pLastCardDate) <> 5) THEN
            ERROR(Text011, FIELDCAPTION("Expiry Date"));

        IF (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 1, 1))) OR (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 2, 1))) OR
          (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 4, 1))) OR (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 5, 1))) THEN
            ERROR(Text011, FIELDCAPTION("Expiry Date"));

        EVALUATE(_Int, COPYSTR(pLastCardDate, 1, 2));

        IF (_Int > 12) OR (_Int < 0) THEN
            ERROR(Text012, FIELDCAPTION("Expiry Date"));
        EVALUATE(_Int, COPYSTR(pLastCardDate, 4, 2));
        _Int += 2000;

        IF (_Int > 2099) OR (_Int < 2000) THEN
            ERROR(Text013, FIELDCAPTION("Expiry Date"));

        EXIT(COPYSTR(pLastCardDate, 4, 2) + COPYSTR(pLastCardDate, 1, 2));
    end;

    procedure ConvertLastDateFromParameter(pLastCardDate: Text[5]): Text[5]
    begin
        IF STRLEN(pLastCardDate) <> 4 THEN
            EXIT(pLastCardDate);

        EXIT(COPYSTR(pLastCardDate, 3, 2) + '/' + COPYSTR(pLastCardDate, 1, 2));
    end;
}

