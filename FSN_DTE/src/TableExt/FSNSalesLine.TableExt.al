tableextension 50144 "FSN Sales Line" extends "Sales Line"
{
    fields
    {
        field(80010; "FSN Base Affect"; Decimal)
        {
            Caption = 'FSN Base Affect';
            trigger OnValidate()
            var
                myInt: Integer;
                SalesHeader: Record "Sales Header";
                Text000: Label 'El Sub Tipo no esta creado en FSN parametro';
                Parameter: Record "FSN Parameter";
            begin
                SalesHeader.Reset;
                SalesHeader.SetRange("No.", Rec."Document No.");
                if SalesHeader.FindFirst() then begin
                    Parameter.Reset();
                    Parameter.SetCurrentKey(Grupo, Codigo);
                    Parameter.SetRange(Grupo, 'SUBTYPE');
                    Parameter.SetRange(Codigo, SalesHeader."Sub Type");
                    IF not Parameter.FindFirst() and (Rec."FSN Base Affect" <> 0.0) then begin
                        Rec."FSN Base Affect" := 0;
                        Message(Text000);
                    end;
                end;
            end;
        }
        field(80011; "FSN fac No"; Code[20])
        {

        }
        field(80012; "FSN Line No"; Integer)
        {

        }
    }

    var
        myInt: Integer;


    trigger OnModify()
    var
        myInt: Integer;
    begin
        Validate("FSN Base Affect");
    end;

}