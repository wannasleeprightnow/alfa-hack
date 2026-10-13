import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { App } from './App'
afterEach(cleanup)
describe('418 poster', () => {
  it('shows one screen with the slogan', () => {
    render(<App />)
    expect(screen.getByRole('heading', { name: '418 is going to rob a bank.' })).toBeInTheDocument()
    expect(screen.queryByText(/scroll to explore/i)).not.toBeInTheDocument()
    expect(screen.getAllByRole('heading')).toHaveLength(1)
  })
})
