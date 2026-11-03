package svc

func Lookup(id string) {
	_ = save(id)
	ctx := context.Background()
	fmt.Println(ctx)
	panic("todo")
}
