tableextension 50048 "FSN POSTransLine Card Ext" extends "LSC POS Trans. Line"
{
    fields
    {
        field(50000; "FSN PC Entry No."; Integer)
        {
            Description = 'Pos card entry No.';
            DataClassification = ToBeClassified;
        }
        field(50001; "FSN PC Request Entry"; Text[150])
        {
            Description = 'Combination key, POS Card Request entry';
            DataClassification = ToBeClassified;
        }
        field(50002; "FSN PC Original Amount"; Decimal)
        {
            Description = 'Voucher original amount';
            DataClassification = ToBeClassified;
        }
        field(50003; "FSN PC Information"; Text[150])
        {
            Description = 'Authorization,Reference No.,LastDate,CVV,CardNo';
            DataClassification = ToBeClassified;
        }
        field(50004; "FSN PC Authorization Ok"; Option)
        {
            OptionMembers = " ",Ok,ManualOk,WithoutAuthorization;
            DataClassification = ToBeClassified;
        }
        field(50005; "FSN PC Encrypt Security"; Text[500])
        {
            DataClassification = ToBeClassified;
        }
        field(50006; "FSN PC Aditional Description"; Text[150])
        {
            DataClassification = ToBeClassified;
        }
        field(50007; "FSN token Wompi"; Boolean)
        {
            DataClassification = ToBeClassified;
        }

        field(50008; "FSN token Message"; Boolean)
        {
            DataClassification = ToBeClassified;
        }
    }

}