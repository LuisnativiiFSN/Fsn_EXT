dotnet
{
    assembly(mscorlib)
    {
        type("System.Convert"; sysConvert)
        {
            IsControlAddIn = false;
        }
        type("System.String"; sysString)
        {
            IsControlAddIn = false;
        }
        type("System.Byte[]"; sysByteArray)
        {
            IsControlAddIn = false;
        }
        type("System.Text.Encoding"; sysEncoding)
        {
            IsControlAddIn = false;
        }
        type("System.IO.Directory"; sysDirectory)
        {
            IsControlAddIn = false;
        }
    }
    assembly("System.Data")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Data.SqlClient.SqlConnection"; "SqlConnection2")
        {
        }

        type("System.Data.SqlClient.SqlCommand"; "SqlCommand2")
        {
        }

        type("System.Data.SqlClient.SqlDataReader"; "SqlDataReader2")
        {
        }
    }
}