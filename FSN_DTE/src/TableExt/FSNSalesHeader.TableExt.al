
tableextension 50106 "FSN Sales Header" extends "Sales Header"
{
    fields
    {
        field(60000; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';

            DataClassification = ToBeClassified;
        }
        field(60001; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';

            DataClassification = ToBeClassified;
            trigger OnValidate()

            begin
                Rec."External Document No." := Rec."DTE Invoice";
            end;

        }
        field(60002; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
            DataClassification = ToBeClassified;
        }
        field(60003; "FSN Internal Control"; Text[50])
        {
            Caption = 'FSN Internal Control';
            DataClassification = ToBeClassified;
        }
    }
}