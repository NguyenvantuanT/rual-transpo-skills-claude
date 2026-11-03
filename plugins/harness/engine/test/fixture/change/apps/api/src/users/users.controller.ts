@Controller('users')
export class UsersController {
  private readonly svc = new UsersService()
  @Post() create(@Body() body: any) {
    if (!process.env.API_KEY) throw new Error('no key')
    return this.svc.create(body)
  }
}
