page 50077 "FSN Comentario Call"
{
    PageType = CardPart;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Rlshp. Mgt. Comment Line";
    InsertAllowed = true;
    //SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(COMENTARIO)
            {
                field(Comment; Comment)
                {
                    Style = Strong;
                    StyleExpr = 'Favorable';
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        Comentario := Comment;
                        InsertDatos();
                    end;
                }
                field(Date; Date)
                {
                    Editable = false;
                }
            }
        }
    }

    var
        POSSESSION: Codeunit "LSC POS Session";
        Linea: Integer;
        Comentario: text[80];

    trigger OnOpenPage()
    var
        myInt: Integer;
        pRecRef: RecordRef;
        POSSESSION: Codeunit "LSC POS Session";
    begin
        FILTERGROUP(2);
        SETRANGE("No.", POSSESSION.GetValue('PHONEORDER'));
        FILTERGROUP(0);
    end;

    procedure InsertDatos()
    var
        myInt: Integer;
    begin
        If Rec.Comment <> '' then begin
            if Rec."Line No." = 0 then begin
                IF Rec.FIND('+') THEN
                    Rec."Line No." := Rec."Line No." + 100;
                if Rec."Line No." = 0 then
                    Rec."Line No." := 100;
                Rec."No." := Rec."No.";
                Rec."Table Name" := Rec."Table Name"::Contact;
                Rec."Sub No." := 0;
                Rec.Date := Today;
                Rec."Last Date Modified" := Today;
                Rec.Comment := Comentario;
                If Rec."Line No." <> 100 then
                    Rec.Insert();
            end else
                Rec.Modify();
        end;
    end;
}