def lambda_handler(event, context):
    print("Event received")
    print(event)
    return{
            "sourceCode":200, 
            "body":"Event received correctly"
    }
