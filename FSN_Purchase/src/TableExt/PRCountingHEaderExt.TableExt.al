/// <summary>
/// TableExtension FSN P/R Counting Header Ext (ID 50051) extends Record LSC P/R Counting Header.
/// </summary>
tableextension 50051 "FSN P/R Counting Header Ext" extends "LSC P/R Counting Header"
{
    fields
    {
        field(300; "SubTotal"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(301; "Tax"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(303; "Total"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(400; "ConfirmarSubTotal"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(401; "ConfirmarTax"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(402; "ConfirmarTotal"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(60000; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';
        }
        field(60001; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';

        }
        field(60002; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
            DataClassification = ToBeClassified;

        }

        field(60003; "FSN Reason Option"; Option)
        {
            OptionCaption = 'None,Costo no Cuadra,Producto no solicitado,Faltante Fisico,Courier,Otros';
            OptionMembers = "None","Costo no Cuadra","Producto no solicitado","Faltante Fisico",Courier,"Otros";

        }
        field(60004; "FSN Reason"; Text[60])
        {
            Caption = 'Descripcion de Rechazo';
            DataClassification = ToBeClassified;

        }
        field(60010; "Associated Credit Memo"; Boolean)
        {
            Caption = 'Associated Credit Memo';
            DataClassification = ToBeClassified;
        }
        field(60011; "No. Credit Memo Associated"; Text[60])
        {
            Caption = 'No. Credit Memo Associated';
            DataClassification = ToBeClassified;

        }
        field(60012; "FSN Status"; Option)
        {
            Caption = 'Status';
            OptionCaption = 'Ninguno,AplicandoAutomatico...';
            OptionMembers = Ninguno,AplicandoAutomatico;
        }

        field(60013; "FSN Message Process"; Text[250])
        {
            Caption = 'FSN Message Process';
        }

        field(60014; "FSN Authorized Reception"; Boolean)
        {
            Caption = 'FSN Recepción Autorizada';
            DataClassification = ToBeClassified;
        }
        field(60015; "FSN Automatic Search"; Boolean)
        {
            DataClassification = ToBeClassified;
            Caption = 'FSN Automatic Search';
        }
        field(60016; "FSN Date Authorized"; DateTime)
        {
            DataClassification = ToBeClassified;
            Caption = 'FSN Date Authorized';
        }
        field(60017; "FSN Shared with EBS"; Boolean)
        {
            DataClassification = ToBeClassified;
            Caption = 'FSN Shared with EBS';
        }

        field(60018; "FSN Count AplitAunt"; Integer)
        {
            DataClassification = ToBeClassified;
            Caption = 'FSN Count AplitAunt';
        }
        field(60019; "FSN DTE Manual"; Boolean)
        {
            DataClassification = ToBeClassified;
            Caption = 'FSN DTE Manual';
        }

    }
    keys
    {
        key(Key9; "FSN Count AplitAunt")
        {
        }
    }

}